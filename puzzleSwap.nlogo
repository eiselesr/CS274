;; end simulation at 1440 - done
;; scatter plot knowledge of studnets againts chance of learning - done
;; code commentary
;; Friend network?
;; color students based on type - done
;; look over slides and paper
;; try for more realistic behavior

extensions [array]
breed [students student]
students-own[  
  ;;--SOCIAL energy factors--
  socialStamina ;; Maximum energy student has for social activities
  socialNrg ;; Current energy for social activities
  socialDrain ;; Social energy lost after performing a social activity for one time tick
  socialRecover ;; Social energy gained while resting
  consultTime ;; average time to spend with the professor
  collabTime ;; average time to spend with a peer
  collabDev ;; standard deviation for time spent with peers
  consultDev ;; standard deviation for time spent with professor
  ;;--MENTAL energy factors--
  mentalStamina ;; Maximum energy student has for mental activities
  mentalNrg ;; Current energy for mental activities
  mentalDrain ;; Mental energy lost after performing a social activity for one time tick
  mentalRecover ;; mental energy gained while resting
  readTime ;; average time to spend reading
  readDev ;; standard deviation for time spent reading
  ;;--Learning factors--
  ;;ZPD slider value
  chanceOfLearning ;; probability of student increasing in knowledge
  chanceOfQuestion ;; probability of student having a question
  knowledge ;; The amount of knowledge obtained
  question ;; question difficulty level
  level ;; floor (knowledge / 10)
  bestLevel ;; The highest value level has had
  collabX ;; A multiplier that is used when reading with a partner to affect the chance of learning
  questionX ;; A mulitiplier that is used when the student has a question to affect the chance of learning
  ;;--Preferences--
  class ;; group of lazy vs smart for example
  restPref
  consultPref
  collabPref
  readPref
  ;;--Other--
  partner ;; who, if anyone, is the students partner
  state ;; The state of a student {read, collaborate, consult, rest}
  options ;; Not acutally used, but these are the activities that a student could choose at the end of the choose-activity function
  time ;; How long an activity will last if it is uninterupted. 
  status ;; an extra varible to see if the agent is moving or waiting.
  restTimer ;; tracks the consecutive number of ticks for which a student chooses rest
  ]
breed [professors professor]

;;-----------------------------------------------------------------------------------------------------------
;;   SETUP 
;;-----------------------------------------------------------------------------------------------------------
to setup
  clear-all
  stop-inspecting-dead-agents
  setup-professor 
  setup-students "A" preflist-A numA red
  setup-students "B" preflist-B numB blue
  reset-ticks
end

;;-----------------------------------------------------------------------------------------------------------
;;   SETUP FOR STUDENTS.
;;-----------------------------------------------------------------------------------------------------------
to setup-students [classVal Prefs NumStudents visual] ;;rest consult collab read
  set-default-shape students "person-read"
  create-students NumStudents
  [
    setxy random-xcor random-ycor;; Distribute students in world
    
    set socialStamina 1440 ;;social energy maximum
    set socialNrg socialStamina ;; current social energy    
    set socialRecover 3;; Same for all students
    set collabTime 30
    set collabDev 15    
    set consultTime 15
    set consultDev 5
    
    set mentalStamina 1440 ;;mental energy maximum
    set mentalNrg mentalStamina ;; current mental energy
    
    ifelse(consumeEnergy)[
      set mentalDrain ceiling (10 * (random-beta 10)) ;; when studying, rate at which energy is lost
      set socialDrain ceiling (10 * (random-beta 10)) ;; when socializing, rate at which energy is lost
    ]
    [set mentalDrain 0 set socialDrain 0]
     
    ;;set mentalDrain 
    set mentalRecover 3;; Same for all students
    set readTime 30;
    set readDev 5
    
    set chanceOfLearning random-float 1 ;; uniform distribution between 0 and 1
    set chanceOfQuestion random-float 1 ;;
    set knowledge 0 ;;
    set question 0 ;; No question to start simulation
    set level 0 ;; level = knowledge/10
    set bestLevel 0 ;; bestLevel = highest level reached
    set collabX 1.1 ;; Collaborating makes learning more effective
    set questionX 1.2 ;; Studying with a question in mind makes learning more effective and draining
    
    ;;set restPref (random 10) + 1 ;; 1-10
    set restPref item 0 Prefs
    set consultPref item 1 Prefs
    set collabPref item 2 Prefs
    set readPref item 3 Prefs
    set class classVal
    set color visual
    
    set partner nobody
    set state "rest" 
    ;; set color grey   
    set time 0
    set status ""    
  ]
  ask students [choose-activity]
  ;;ask students [inspect self] ;;inspect student # for all students
  ;;ask students [ set lambda .01]
  ;;ask students [ set mem-array array:from-list n-values 16 [0]]
end

;;-----------------------------------------------------------------------------------------------------------
;;   SETUP FOR PROFESSOR
;;-----------------------------------------------------------------------------------------------------------
to setup-professor
  set-default-shape professors "person graduate"
  create-professors 1
end

;;-----------------------------------------------------------------------------------------------------------
;;   GO - THESE RUN AT EVERY TICK. A TICK REPRESENTS 1 MINUTE
;;-----------------------------------------------------------------------------------------------------------
to go  
  ask students [set time time - 1]
  ask students [ if(level >= question)[set question 0]] ;; if my lvl is equal to or higher than the question, the question is resolved.
  ask students [set bestLevel max list level bestLevel] ;; Update bestLevel
  
  ;;Mental drain goes down while reading. status can be "move" "wait" or "". This means that mental energy also goes down in collaborate and consult when the state
  ;; is entered the first time, and when the student is close enough to the partner to work. Traveling doesn't consume energy 
  ask students [if((state = "collaborate" and status = "") or state = "read" or (state = "consult" and status = "")) [set mentalNrg mentalNrg - mentalDrain ]]
  
  ;; Social energy is consumed when a student has a partner, and the status is not "move" or "wait"
  ask students [if((partner != nobody) and status = "")[set socialNrg socialNrg - socialDrain]]
  
  do-activity ;; Calls do-activity
  tick
  if(ticks > 1440)[stop] ;; stops the simulation after 1440 "minutes"
end

;;-----------------------------------------------------------------------------------------------------------
;;   CHOOSE THE NEXT ACTIVITY
;;-----------------------------------------------------------------------------------------------------------
to choose-activity  
  ;;user-message (word "choose-activity " who)
  set options []
  set time 0
  let nearest-neighbor min-one-of (other students with [ socialNrg > (collabTime * socialDrain)and (mentalNrg > (collabTime * mentalDrain)) and (state = "read" or state = "rest") and (partner = nobody)])[distance myself];; Find the closest student of the students with state
  
  ;; these are used like switches. 0 means the activity cannot be selected. 1 means the probability of the activity is the preferance number divided the sum of all possible pref numbers
  let a 0 ;; read
  let b 0 ;; collab
  let c 0 ;; consult
  ;;-------READ---------------------------
  if(mentalNrg - (readTime * mentalDrain)) > 0 ;; in order to read you must have enough mental energy to last for an average reading session
  [set options lput "read" options 
   set a 1 ]
  
  ;;-------COLLABORATE--------------------
  if(nearest-neighbor != nobody)
  [    
    ;; in order to collaborate we must have enough energy to complete an average collaborate session
    ;;if(socialNrg >= (collabTime * socialDrain + distance nearest-neighbor) and (mentalNrg > (collabTime * mentalDrain + distance nearest-neighbor)))
    if(socialNrg >= (collabTime * socialDrain) and (mentalNrg > (collabTime * mentalDrain))) ;; dont need above equation if there is no energy lost while moving
    [set options lput "collaborate" options
     set b 1]
  ]  
  
  ;;-------CONSULT----------------
  let prf_distance distance one-of professors
  
  ;; Must have enough energy for an average consult session, and a question
  ;;if((socialNrg >= (consultTime * socialDrain + prf_distance) and (mentalNrg > (consultTime * mentalDrain + prf_distance))) and question > 0)
  if((socialNrg >= (consultTime * socialDrain) and (mentalNrg > (consultTime * mentalDrain))) and question > 0)
  [ set options lput "consult" options
    set c 1]
  
  ;;-------REST-------------
  set options lput "rest" options
  
  ;;-------------------------------------------------------
  ;;            CHOOSE
  ;; example: total = 2 2 0 2 = 6
  ;; readLim = 2 collabLim = 4 consultLim = 4
  ;; 0< choice <= 2 -> state = "read"
  ;; 2< choice <= 4 -> state = "collaborate"
  ;; 4< choice <= 4 -> not possible so -> state = "rest"
  ;; if choice = 1 -> state = "read"
  ;; if choice = 2 -> state = "read"
  ;; if choice = 3 -> state = "collaborate"
  ;; if choice = 4 -> state = "collaborate"
  ;; if choice = 5 -> state = "rest"
  ;; if choice = 6 -> state = "rest"
  ;; P(rest) = P(collaborate) = P(rest) 33%
  ;;-------------------------------------------------------
  let total (a * readPref) + (b * collabPref) + (c * consultPref) + restPref
  let readLim  (a * readPref)
  let collabLim (b * collabPref) + readLim
  let consultLim (c * consultPref) + collabLim
  
  let choice (random total) + 1
   ifelse(choice > 0           and (choice <= readLim))   [set state "read" set time ceiling(random-normal readTime readDev)  ]
  [ifelse(choice > (readLim)   and (choice <= collabLim)) [set state "collaborate" set time ceiling(random-normal collabTime collabDev)]
  [ifelse(choice > (collabLim) and (choice <= consultLim))[set state "consult" set time ceiling(random-normal consultTime consultDev)] ;; COULD SET ANOTHER TIME AND DEVIATION PARAMETER
  [set state "rest" ;; default case
  ]]]  
  
  ;;--------------------------------------------------------------
 
  if(state != "rest") ;; increment the rest timer for each consecutive selection of the rest activity
  [set restTimer 0]
  ;;user-message (word "end choose-activity: " who " is " state)
  
;  set level floor (knowledge / 10)
end

;;-----------------------------------------------------------------------------------------------------------
;;   DO THE ACTIVITY
;;-----------------------------------------------------------------------------------------------------------
to do-activity  
  foreach sort students
  [
    ask ?
    [      
      ;;-------READ-------------
      if (state = "read") [read]
      ;;-------COLLABORATE--------------------
      if (state = "collaborate") [collaborate]  
      ;;-------CONSULT----------------
      if (state = "consult") [consult]
      ;;-------REST-------------
      if (state = "rest") [rest]
    ]
  ]  
end

;;-----------------------------------------------------------------------------------------------------------
;;   READ
;;-----------------------------------------------------------------------------------------------------------
to read  
  
  ;; If this becomes true, clean up and choose a new activity
  if (time <= 0 or (mentalNrg <= 0)) 
  [
    choose-activity 
    if (partner != nobody) ;; 
    [ ask partner [choose-activity]
      ask partner [set partner nobody]
      set partner nobody
    ]
    stop
  ]
      
  let multiplier 1
  ;; set color red
  if (question > level)[set multiplier questionX] ;; affect chance of learning when student has a question
  if (partner != nobody)[set multiplier collabX] ;; affect chance of learning when student has a partner
  
  ;; See if the student learns something
  if ((1 - chanceOfLearning * multiplier) <= (random-float 1))[ 
    set knowledge knowledge + 1 
    set level floor(knowledge / 10)]
  
  ;; See if the student has a question
  if((1 - chanceOfQuestion) < (random-float 1) and question = 0 and partner = nobody) ;; try to generate a question if I have no partner and no question
  [
    set question ceiling(random-normal level ZPD) ;; determine question difficulty
    ifelse(question > level) [choose-activity stop]  ;; If the question is higher than my level choose a new activity
    [set question 0] ;;Otherwise ignore the question    
   ] 
  
  
end

;;-----------------------------------------------------------------------------------------------------------
;;  REST
;;-----------------------------------------------------------------------------------------------------------
to rest 
  ;; set color grey
  ifelse((mentalNrg < mentalStamina) and (mentalNrg + mentalRecover)< mentalStamina) ;; increase energy. If increase would go beyond max, set to max. 
  [ set mentalnrg mentalnrg + mentalRecover]
  [ set mentalnrg mentalStamina]
  
  ifelse((socialNrg < socialStamina) and (socialNrg + socialRecover)< socialStamina)
  [set socialNrg socialNrg + socialRecover]
  [ set socialnrg socialStamina]
  
  set restTimer restTimer + 1
  if(knowledge > 0 and (random-float 1 > (.19 + .6318 * ((1 + restTimer)^ -.68))))
    [set knowledge knowledge - 1]
  choose-activity
end

;;-----------------------------------------------------------------------------------------------------------
;;   COLLABORATE
;;-----------------------------------------------------------------------------------------------------------

to collaborate
  ;;if(status = "")[set socialNrg socialNrg - socialDrain] ;; only drain social energy when together, and when setting up connection
  
  
  if(time <= 0 or (socialNrg <= 0) or (mentalNrg <= 0))
  [choose-activity
    if (partner != nobody) ;; need to check because it possible to enter this block before a partner is set
    [ ask partner [choose-activity]
      ask partner [set partner nobody]
      set partner nobody
      stop]]
  
  if partner = nobody
  [
    ;; For a partner, choose the closest student that has enough energy to collaborate and is in the read, or rest state.
    set partner min-one-of (other students with [ (socialNrg > (collabTime * socialDrain)) and (mentalNrg > (collabTime * mentalDrain)) and (state = "read" or state = "rest")])[distance myself];; Find the closest student of the students with state
    
    ;; if there is a student that meets the requirements have them set me as a partner, otherwise choose a new activity
    ifelse(partner != nobody) ;; 
    [ set status "move" 
      set time ceiling(time + distance partner)
      
      ask partner [set partner myself] 
      ask partner [set status "wait" set state "collaborate" set time [time] of partner] 
     ]
    [choose-activity stop]    
  ] 
  
  if(status = "move")
  [move]
  
  if(status = "wait" and (distance partner < 2))
  [set status ""]
  
  if(level < [level] of partner) ;; if my level is lower, increase knowledge. 
  [
    ;;set mentalNrg mentalNrg - mentalDrain
    set knowledge knowledge + 1
    set level floor(knowledge / 10)
    ;; set color red
  ]  
  
  if(level > [level] of partner);; if my level is higher, but lower than the highest I've head increase knowledge
  [
    ;; set color green 
    if(level < bestLevel)
    [set knowledge knowledge + 1 set level floor(knowledge / 10)]
    
    ;;set mentalNrg mentalNrg - mentalDrain
  ]
  
  if(level = [level] of partner and status = "") ;; if we are the same, switch to partner reading
  [set state "read"]
  
end


;;-----------------------------------------------------------------------------------------------------------
;;   MOVE
;;-----------------------------------------------------------------------------------------------------------
to move
  if(partner = nobody)
  [forward 1]
  ;;[set color blue forward 1]
  
  if(partner != nobody)
  [
    ifelse(distance partner > 2)
    [face partner forward 1]
    ;;[set color blue face partner forward 1]
    [set status ""]  ;; signals when the partners are close enough. 
  ]
end

;;-----------------------------------------------------------------------------------------------------------
;;   CONSULT
;;-----------------------------------------------------------------------------------------------------------
to consult
  
  ;; If this becomes true, clean up and choose a new activity
  if(time <= 0 or (socialNrg <= 0) or (mentalNrg <= 0))
  [choose-activity
    if (partner != nobody) ;; need to check because it possible to enter this block before a partner is set
    [set partner nobody]
    stop
  ]
  
  ;; This occurst the first time the function is run after choosing the activity
  if(partner = nobody and question != 0)
  [ set partner one-of professors
    set status "move"
    set time ceiling(time + distance partner)]
  
  ;; This occurs to get the student close to the teacher
  if(status = "move" and time > 0)
  [move stop]
  
  ;; If the student has a question then...
  if(question != 0)
  [
    set level min (list question (level + ZPD) );; set the students level to the question level or the level + zpd whichever is smaller.
    if(level >= question)[set question 0] ;; Check to see if question was answered.
    set knowledge level * 10 ;; update knowldge to match
    set partner nobody ;;clean up
    set time random 10 + 5;; time to move away from prof, or if there is still a question how long the next session will last
    set heading random 360
    set status "move"
  ]
  
  if(question = 0 and time <= 0) ;; This is so the student can move away after getting having their question answered. I think. I don't remember right now. You might be able to delete this.
  [choose-activity] 
  
end


;;-----------------------------------
;;   BETA VALUE GENERATOR FUNCTION
;;-----------------------------------
to-report random-beta [alpha]
  let x random-gamma alpha 1
  
  report ( x / ( x + random-gamma alpha 1) )   
end

;;-------------------------------------------------------------
;;   FUNCTIONS CALLED PLOTS in GUI
;;-------------------------------------------------------------
to plot-LearnChanceVsKnowledge
  clear-plot
  set-current-plot "LearnChanceVsKnowledge"
  ask students [set-current-plot-pen class plotxy chanceofLearning knowledge]
end

to plot-QuestionChanceVsKnowledge
  clear-plot
  ask students [set-current-plot-pen class plotxy chanceofQuestion knowledge]
end
@#$#@#$#@
GRAPHICS-WINDOW
21
203
354
557
16
16
9.8
1
10
1
1
1
0
1
1
1
-16
16
-16
16
1
1
1
ticks
30.0

BUTTON
19
10
83
44
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
83
10
147
44
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

PLOT
624
72
1008
295
Average Energy levels over time
time
energy
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"mental-A" 1.0 0 -16777216 true "" "plot mean [mentalNrg] of students"
"social-A" 1.0 0 -408670 true "" "plot mean [socialNrg] of students"

SLIDER
225
10
397
43
ZPD
ZPD
0
5
1
1
1
NIL
HORIZONTAL

BUTTON
149
10
224
43
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
279
70
439
190
MentalDrain
value
count
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -7858858 true "" "histogram [mentalDrain] of students"

PLOT
364
238
611
388
Knowledge Change
time
knowledge
0.0
50.0
0.0
10.0
true
true
"" ""
PENS
"s1" 1.0 0 -4699768 true "" "plot [knowledge] of student 1"
"mean-ALL" 1.0 0 -7500403 true "" "plot mean [knowledge] of students"

PLOT
364
401
612
551
# in activity now
activity
# students
0.0
10.0
0.0
10.0
true
true
"" "clear-plot"
PENS
"read" 1.0 1 -16777216 true "" "plotxy 1 count students with [state = \"read\"]"
"consult" 1.0 1 -7500403 true "" "plotxy 3 count students with [state = \"consult\"]"
"collab" 1.0 1 -2674135 true "" "plotxy 5 count students with [state = \"collaborate\" ]"
"rest" 1.0 1 -14454117 true "" "plotxy 7 count students with [state = \"rest\"]"

PLOT
624
308
1009
551
# of "A" students in each activity
time
count
0.0
1450.0
0.0
10.0
true
true
"" ""
PENS
"read" 1.0 0 -16777216 true "" "plot count students with [class = \"A\" and state = \"read\" and partner = nobody]"
"consult" 1.0 0 -8630108 true "" "plot count students with [class = \"A\" and state = \"consult\"]"
"collab" 1.0 0 -817084 true "" "plot count students with [class = \"A\" and is-student? partner]"
"rest" 1.0 0 -10899396 true "" "plot count students with [class = \"A\" and state = \"rest\"]"

SWITCH
398
10
541
43
consumeEnergy
consumeEnergy
0
1
-1000

PLOT
1021
72
1322
294
LearnChanceVsKnowledge
chanceOfLearning
knowledge
0.0
1.0
0.0
400.0
true
true
"" "plot-LearnChanceVsKnowledge"
PENS
"A" 1.0 2 -2674135 true "" ""
"B" 1.0 2 -13791810 true "" ""

PLOT
1021
307
1323
526
Chance of Question
NIL
NIL
0.0
1.0
0.0
400.0
true
true
"" "plot-QuestionChanceVsKnowledge"
PENS
"A" 1.0 2 -2674135 true "" ""
"B" 1.0 2 -13791810 true "" ""

CHOOSER
20
144
141
189
preflist-A
preflist-A
[6 2 2 2] [6 1 4 1] [6 1 1 4] [3 3 3 3] [3 2 5 2] [3 2 2 5]
0

CHOOSER
150
144
271
189
preflist-B
preflist-B
[6 2 2 2] [6 1 4 1] [6 1 1 4] [3 3 3 3] [3 2 5 2] [3 2 2 5]
0

SLIDER
20
86
141
119
numA
numA
0
50
20
1
1
NIL
HORIZONTAL

SLIDER
149
86
270
119
numB
numB
0
50
0
1
1
NIL
HORIZONTAL

TEXTBOX
38
127
250
155
SET: [Rest, Consult, Collaborate, Read]
11
0.0
1

TEXTBOX
38
70
245
98
SET: number of red and blue students
11
0.0
1

PLOT
448
71
608
191
SocialDrain
value
count
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram [socialDrain] of students"

TEXTBOX
1027
26
1304
69
How does final knowledge depend on Individual characteristics?
16
32.0
0

TEXTBOX
649
31
1005
91
How does activity choice change over time?
16
32.0
1

TEXTBOX
625
559
1030
584
How does final knowledge depend on preferences?
16
33.0
1

TEXTBOX
432
207
582
227
Live Monitors
16
32.0
1

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

person graduate
false
0
Circle -16777216 false false 39 183 20
Polygon -1 true false 50 203 85 213 118 227 119 207 89 204 52 185
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -8630108 true false 90 19 150 37 210 19 195 4 105 4
Polygon -8630108 true false 120 90 105 90 60 195 90 210 120 165 90 285 105 300 195 300 210 285 180 165 210 210 240 195 195 90
Polygon -1184463 true false 135 90 120 90 150 135 180 90 165 90 150 105
Line -2674135 false 195 90 150 135
Line -2674135 false 105 90 150 135
Polygon -1 true false 135 90 150 105 165 90
Circle -1 true false 104 205 20
Circle -1 true false 41 184 20
Circle -16777216 false false 106 206 18
Line -2674135 false 208 22 208 57

person student
false
0
Polygon -13791810 true false 135 90 150 105 135 165 150 180 165 165 150 105 165 90
Polygon -7500403 true true 195 90 240 195 210 210 165 105
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -1 true false 100 210 130 225 145 165 85 135 63 189
Polygon -13791810 true false 90 210 120 225 135 165 67 130 53 189
Polygon -1 true false 120 224 131 225 124 210
Line -16777216 false 139 168 126 225
Line -16777216 false 140 167 76 136
Polygon -7500403 true true 105 90 60 195 90 210 135 105

person-read
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -2674135 true false 75 135 90 150 135 165 135 150 105 135 120 105 105 90
Polygon -2674135 true false 225 135 210 150 165 165 165 150 195 135 180 105 195 90
Polygon -13345367 true false 129 130 130 184 153 192 171 186 172 130 156 139 130 131

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
