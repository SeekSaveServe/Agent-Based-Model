turtles-own ;; define tutrle variable
[ sick? ;; boolean, 1 infected else 0
  immune? ;; boolean, 1 infected else 0
  symptomatic? ;; boolean, 1 symptomatic else 0
  symptomaticTested? ;; to check if the turtle did the symptomatic test
  quarantine? ;; is the turtle in quarantine
  vaccinated? ;; if the turtle has been vaccinated
  spreader? ;; super-spreader event
  quarantineDays ;; days turtle has been under quarantine
  sickDays ;; #days turtle has been infected
  immuneDays ;; #days turtle has been immune
             ;; driver var
  zone ;; 0-3 to represent a zone they are in, only those from the same zone can be infected
  restTime
  rested? ;; ensure they rest once every hub
  no-skip ;; number of stops to skip needs to be alternated beteen x and x' s.t x + x' = 8
  cur-skip ;; cur stops skipped
]

patches-own
[
  land-type ;; 0 for road 1 for transport hub 2 for otherwise
]


globals ;; global variable
[
  %infected  ;; % of population infected
  %immune ;; % of population immune
  deaths ;; the total number of deaths
  population ;; the total population alive
  all-quarantine ;; all turtles on quarantine
  all-infected;; the total number of infected individuals from the start
  all-symptomatic ;; total symptomatic
  total-mild ;; total mild symptoms (hospitalised)
  total-severe ; ICU bed
  infectiousness ;; need to be separated out to prevent the "auto-reducing" bug caused by enabling mask-wearing
  hub-y ;; x coordinates of hubs
  hub-x  ;; y coordiantes of hubs
  road-y-boarder ;; y coordinates of roads
  road-x-boarder ;; x coordinates of roads
  road-x-top
  road-y-top
  temp ;; counter variable for all occassions
  temp2 ;; bcoz netlogo is strong-dynmically typed
]

to setup
  clear-all
  set hub-y [14 -14]
  set hub-x [-14 -4 4 14]
  set road-x-top [-13 -12 -11 -10 -9 -8 -7 -6 -5 -3 -2 -1 0 1 2 3 5 6 7 8 9 10 11 12 13]
  set road-y-top [-14 14]
  set road-x-boarder [-14 14]
  set road-y-boarder [-13 -12 -11 -10 -9 -8 -7 -6 -4 -5 -3 -2 -1 0 1 2 3 4 5 6 7 8 9 10 11 12 13]

  setup-patches ;; subroutine that setsup turtles
  setup-turtles ;; subroutine that setsup turtles
  update-global-variables ;; subroutine that sets up global var
  set all-infected count turtles with [sick?]
  ;; if mask on we alter the infectiousness
  ifelse mask
  [set infectiousness (infectiousness-init * mask-effect)] ;; done this way so we do not change infectiousness-init
  [set infectiousness infectiousness-init]
  reset-ticks
end

to setup-turtles
  set-default-shape turtles "arrow" ;; so we can see the direction of travel
  setup-drivers

  ask n-of initial-infected turtles ;; 10 can be adjusted to change the initial numbe of sick ppl
  [ifelse super-spreader
    [ set spreader? true ;; super spreaders have a 100% infectious rate and twice the mobility :)
      get-sick
      set color pink ]
    [get-sick] ;; normal spreader
  ]
end

to setup-drivers
  ;; distribute drivers evenly
  crt people [
    setxy (one-of hub-x)  (one-of hub-y) ;; set the coordinates
    set sickDays 0 ;; people are not sick initialy
    set vaccinated? true ;; We assume that all drivers are vaccinated
    become-immune ;; for the purpose of our simulation, we assume that drivers will not lose immunity
    set symptomatic? false
    set quarantine? false
    set symptomaticTested? false ;;this is also set to false upon re-infection
    set spreader? false
    set rested? true ;; assume they rested before the trip
    set heading ((xcor mod 1) * (ycor mod 1) * 90) ;; face the correct orientation
    set size 1 ;; easier to see
    set no-skip (1 + random 6) ;;assign x to skip-no, where  1<=x<=7

    ifelse zoning ;; if zoning is enabled
    [
      set zone (random 4) ;; assign drivers to a zone
    ]
    [
      set zone 1 ;; else assign everyone the same zone
    ]
  ]
end

to setup-patches
  ask patches [
    ifelse((member? pycor road-y-top) and (member? pxcor road-x-top)) or ((member? pycor road-y-boarder) and (member? pxcor road-x-boarder))  ;; if it is a road patch
    [
      set land-type 0
      set pcolor gray
    ]

    [ifelse (member? pycor hub-y) and (member? pxcor hub-x) ;; if their coordinates are in the hub range
      [
        set land-type 1
        set pcolor orange
      ]
      [set land-type 2 ;; not road or hub
        set pcolor black]
    ]
  ]
end

to get-sick
  set sick? true
  set symptomaticTested? false
  set color red ;; red represents sick people
end

to get-healthy
  set sick? false
  set immune? false
  set sickDays 0
  set color green ;; green represents healthy people
end

to reset
  set sickDays 0 ;; people are not sick initialy
  set vaccinated? true ;; We assume that all drivers are vaccinated
  become-immune ;; for the purpose of our simulation, we assume that drivers will not lose immunity
  set symptomatic? false
  set quarantine? false
  set symptomaticTested? false ;;this is also set to false upon re-infection
  set spreader? false
end

to become-immune
  set sick? false
  set sickDays 0
  set immune? true
  set immuneDays 0
  set color green
end

to become-unimmune
  set sick? false
  set sickDays 0
  set immune? false
  set color green ;; even vaccinated ones go back to green if they lose their immunity
end

to vaccinate
  repeat vaccine-rate [
    ifelse (count turtles with [not sick? and (not immune? or not vaccinated?)]  < 1) ;; not enough turtles
    [stop]
    [ask one-of (turtles with [not sick? and (not immune? or not vaccinated?)])
      [become-immune
        set vaccinated? true];; turtle becomes vaccinated
    ]
  ]
end

to go ;; command to initiate go button
  tick ;; IMPORTANT need to increment time
  get-older ;; turtle procedure to count number of days turtle has been sick
  move-driver ;; normal driver movement
  infect ;;turtle procedure to infect turtles
  remove-symptomatic ;; remove symp drivers / quanrantined ones
  develop-symptoms ;; develop symptoms, will only be removed after 1 tick
  trace ;; trace symptomatic turtles
  quarantine;; release turtle from quarantine
  recover
  update-global-variables

  if count turtles with [sick?] = 0
  [stop]
end

to update-global-variables
  if (count turtles > 0)
  [
    set %infected (count turtles with [sick?]) / (count turtles) * 100
    set %immune (count turtles with[immune?]) / (count turtles) * 100
    set population count turtles
  ]
end

to remove-symptomatic
  ask turtles with [symptomatic? or quarantine?] ;; we remove symptomatic / quarantined drivers from the equation
  [
    reset;; does not matter since we are only interested in infection spread
  ]
end

to get-older
  ask turtles
  [ if sick?
    [ set sickDays (sickDays + 1) ]
    if immune?
    [set immuneDays (immuneDays + 1)]
    if quarantine?
    [set quarantineDays (quarantineDays + 1)]
  ]
end

to move
  ask turtles
  [
    rt random 100 ;; right turn between a random angle 0 - 100
    lt random 100 ;; left turn between 0 - 100 degrees
    ifelse spreader?
    [fd 2] ;; spreaders have twice the mobility
    [fd 1] ;; move forward in current direction by 1 step
  ]
end

to move-sdm
  ask turtles
  [
    rt random 100 ;; right turn between a random angle 0 - 100
    lt random 100 ;; left turn between 0 - 100 degrees
    ifelse spreader?
    [fd 2 * mobility] ;; spreaders have twice the mobility
    [fd mobility]
  ]
end

to move-driver ;; idk how scoping works in netlogo and at this point i m too lazy to figure that out
  ask turtles
  [
    if restTime > 0 ;; still resting
    [
      socialise ;; socialise abd maybe you will get covid
      stop
    ]
    ;;if ticks mod 96 = 0 ;; new day reverse direction
    ;;[
    ;;rt 180 ;; change orientation
    ;; ]

    check-dir ;; check if i am going to the right direction

    if temp = 0 ;; advance 1 step
    [road-move
      stop]
    if temp = 2 ;; turns
    [re-align
      stop]
    if temp = 1 ;; rest at hub
    [hub-move
      stop]
  ]
end

to check-dir ;; need to make them turn correctly

  ask patch-here
  [
    if land-type = 1 ;; hub
    [set temp 1] ;; wow MIPS actly taught me smth useful
    if land-type = 0 ;; road
    [set temp 0]
    if land-type = 2 ;; otherwise
    [set temp 2]
  ]
end

to hub-move
  if cur-skip < no-skip ;; we have not reached the required stop
  [
    re-align ;; find the valid direction
    road-move ;; treat it as a road move
    set cur-skip (cur-skip + 1) ;; increment the # of stop skipped by 1
    stop ;; terminates
  ]
  ;; otherwise, we need to check if the driver is ready to rest
  ;; first we need to set skip-no to its additive inverse, so that we travel the correct number of stops
  set no-skip (8 - no-skip)
  set cur-skip 0 ;; clear the counter

  ;; ensure driver rests every cycle
  ifelse(not rested?)
  [rest] ;; drivers rests at a hub
  [
    set rested?  false ;; driver is now tired
    re-align
    fd 1 ;; he drives on
  ]
end

to road-move
  fd 1 ;; move forward by 1 step
end

to re-align ;; i hope no one reads this garbage code
  while [temp > 0] ;; we have not found the right direction
  [
    ask patch-ahead 1 ;; check the patch infront
    [if land-type = 0 [set temp -1]] ;; faces road now
    if temp > 0
    [rt 90]
  ]
  fd 1 ;; move forward by a step
end

to rest
  ;; first we rng the rest time
  set rested? true
  set restTime (random 6)
end

to socialise
  set restTime (restTime - 1) ;; decrease rest-time by 1
end


to infect
  ask turtles with [sick? and not quarantine?];;quarantined turtles cannot spread
    [
      set temp zone ; temp = zone number. Wow who knew MIPS actly taught me something
      ask other turtles-here with [not quarantine? and restTime > 0 and zone = temp] ;;quarantined turtles cannot be infected, only infect while at hub, and only infect those from same hub
      [ ifelse spreader? ;; super spreader event
        [get-sick] ;; 100% infectivity
        [ ifelse immune?
          ;; immune
          [  if ((random-float 100) * immunity-constant) < infectiousness
            [ get-sick
              set all-infected (all-infected + 1) ]]
          ;; not immune
          [ if (random-float 100)  < infectiousness
            [ get-sick
              set all-infected (all-infected + 1) ]]
        ]
      ]
  ]
end

to recover
  ask turtles with [sick?]
  ;; if turtle survived pas t the vrius' duration then
  ;; it either recovers - in which case it either was asymptomatic, or symptomatic but did not visit the hospital
  ;; or hospitalised for mild symptoms or went to ICU and recovered or
  ;; or went to ICU and died
  [ if (random sickDays) > duration
    [ifelse symptomatic?
      [hospital]
      [become-immune] ;; asymptomatic recovers
    ]
  ]
end

to lose-immunity
  ask turtles with [immune?]
  ;; if the turtle has survived past the immunity's duration
  ;; immunity is lost
  [if immuneDays > immune-time
    [ become-unimmune]
  ]
end

to quarantine
  ask turtles with [quarantine?]
  [if (quarantineDays > quarantine-period)
    [set quarantine? false ;; remove the turtle from quanrantine
      set quarantineDays 0]]
end


to develop-symptoms
  ask turtles with [sick? and not symptomaticTested?]
  ;; if sickDays > incubation period, we run a probability check on being symptomatic
  [if (sickDays >= incubation-period)
    [ifelse immune?
      [if((random-float 100) * immunity-constant < chance-symptoms)
        [set symptomatic? true
          set all-symptomatic (all-symptomatic + 1)]
        set symptomaticTested? true] ;; this is so that my code will not run the probability test to make turtles symptomatic twice
                                     ;;not immune
      [if((random-float 100)  < chance-symptoms)
        [set symptomatic? true
          set all-symptomatic (all-symptomatic + 1)]
        set symptomaticTested? true]]]
end

to trace

  ask turtles with [symptomatic? and not quarantine?]
  ;; if the turtle is sick, we trace every other turtle within 4 step radius and test them
  [
    ifelse zoning
    [
      set temp (zone) ;; we test those in the same zone
      ask turtles with [temp = zone]
      [
        if sick? ;; quarantine those tested sick
          [send-quarantine] ;;quarantine sick turtles

      ]
    ]
    [
      set temp (no-skip) ;; temp will be the criteria we use to contact trace. the criteria is same no-skip (route)
      ask turtles with [(no-skip = temp)] ;; turtles that fits the criteria
      [if sick? ;; quarantine those tested sick
        [send-quarantine] ;;quarantine sick turtles
      ]
    ]
  ]
end

to send-quarantine
  set quarantine? true ;; sent the turtle to quarantine
  set color yellow
  set quarantineDays 0
  set all-quarantine (all-quarantine + 1)
end
to hospital
  ifelse immune?
  [ifelse ((random-float 100) * immunity-constant < chance-mild)
    [ set total-mild (total-mild + 1) ;; increment total mild by 1
      icu] ;; check if turtle will go to ICU
    [become-immune]]  ;; else recovers
                      ;; not immune
  [ifelse ((random-float 100) < chance-mild)
    [ set total-mild (total-mild + 1) ;; increment total mild by 1
      icu]
    [become-immune]]  ;; else recovers
end

to icu
  ifelse immune?
  [ifelse ((random-float 100) * immunity-constant < chance-severe)
    [ set total-severe (total-severe + 1) ;; increment total severe by 1
      death] ;; check if turtle will die
    [become-immune]]  ;; else recovers ;; check if turtle will die
                      ;; not immune
  [ifelse ((random-float 100) < chance-severe)
    [ set total-severe (total-severe + 1) ;; increment total severe by 1
      death]
    [become-immune]]  ;; else recovers
end

to death ;; need aggregated death rate for immune and non-immune since i do not plan on stratifying by age grp
  ifelse immune?
  [ifelse ((random-float 100) * immunity-constant < chance-death)
    [ set deaths (deaths + 1) ;; increment total death by 1
      die]
    [become-immune]]  ;; else recovers
                      ;; not immune
  [ifelse ((random-float 100) < chance-death)
    [ set deaths (deaths + 1) ;; increment total death by 1
      die]
    [become-immune]]  ;; else recovers
end
@#$#@#$#@
GRAPHICS-WINDOW
315
18
748
452
-1
-1
12.9
1
5
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
Hours
30.0

BUTTON
559
459
623
492
NIL
Setup
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
494
459
557
492
NIL
Go\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1147
456
1214
501
NIL
%immune
5
1
11

MONITOR
1075
456
1146
501
NIL
%infected
5
1
11

SLIDER
0
197
172
230
infectiousness-init
infectiousness-init
0
100
12.0
1
1
%
HORIZONTAL

SLIDER
0
227
176
260
duration
duration
0
1000
336.0
1
1
hours
HORIZONTAL

SLIDER
0
168
172
201
immune-time
immune-time
0
10000000000
1.0E10
1
1
hours
HORIZONTAL

PLOT
748
16
1238
474
population
days
people
0.0
365.0
0.0
200.0
true
true
"" ""
PENS
"sick" 1.0 0 -2674135 true "" "plot count ( turtles with [sick?])"
"immune" 1.0 0 -7500403 true "" "plot count turtles with [immune?]"
"susceptible " 1.0 0 -13840069 true "" "plot count turtles with [not sick? and not immune?]"
"total" 1.0 0 -14454117 true "" "plot count turtles"
"Quarantine" 1.0 0 -1184463 true "" "plot count turtles with [quarantine?]"
"Symptomatic" 1.0 0 -955883 true "" "plot count turtles with [symptomatic?]"
"vaccinated" 1.0 0 -5825686 true "" "plot count turtles with [vaccinated?]"

BUTTON
430
458
493
491
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
1

MONITOR
952
456
1004
501
NIL
Deaths
5
1
11

MONITOR
1004
456
1075
501
NIL
Population
0
1
11

SLIDER
0
138
172
171
quarantine-period
quarantine-period
0
21
21.0
1
1
days
HORIZONTAL

SLIDER
0
105
173
138
incubation-period
incubation-period
0
100
96.0
1
1
hours
HORIZONTAL

SLIDER
0
76
172
109
chance-symptoms
chance-symptoms
0
100
10.0
1
1
%
HORIZONTAL

MONITOR
872
455
951
500
NIL
all-quarantine
17
1
11

MONITOR
710
454
781
499
NIL
all-infected
17
1
11

MONITOR
782
455
875
500
NIL
all-symptomatic
17
1
11

SLIDER
0
45
172
78
initial-infected
initial-infected
0
100
22.0
1
1
NIL
HORIZONTAL

SLIDER
1
11
173
44
vaccine-rate
vaccine-rate
0
100
0.0
1
1
NIL
HORIZONTAL

INPUTBOX
108
363
207
423
immunity-constant
8.0
1
0
Number

INPUTBOX
0
361
50
421
People
3000.0
1
0
Number

SWITCH
0
264
90
297
mask
mask
1
1
-1000

INPUTBOX
49
362
112
422
mask-effect
0.21
1
0
Number

SWITCH
87
264
190
297
sdm
sdm
1
1
-1000

INPUTBOX
0
303
50
363
mobility
0.5
1
0
Number

INPUTBOX
124
302
208
362
chance-severe
50.0
1
0
Number

INPUTBOX
49
303
125
363
chance-mild
100.0
1
0
Number

INPUTBOX
208
302
286
362
chance-death
50.0
1
0
Number

INPUTBOX
206
362
278
422
trace-radius
1.0
1
0
Number

SWITCH
190
264
315
297
super-spreader
super-spreader
1
1
-1000

TEXTBOX
179
76
313
202
Trace criteria has been changed to capture those on the same hub & rest route(if zoning not enabled)\n\nWith zoning, everyone from the same zone is tested
11
0.0
1

SWITCH
191
232
294
265
zoning
zoning
0
1
-1000

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
NetLogo 6.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="30" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="912"/>
    <metric>count turtles with [sick?]</metric>
  </experiment>
</experiments>
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
