; Elephant Behaviors Model with Railway Train and Advanced Controls
; Simulates elephant movement and social behavior with a train on railway tracks

globals [
  water-growth-rate       ; rate at which water patches regenerate
  railway-patches         ; agentset of patches that form the railway line
  model-hour              ; current hour in model time
  model-minute            ; current minute in model time
  ticks-per-minute        ; how many ticks represent one minute
  proximity-count         ; count of elephant-train close approaches
  collision-count         ; count of actual collisions
  total-elephant-ticks    ; total number of elephant time units for probability calculation
  proximity-probability   ; probability of getting close to train
  collision-probability   ; probability of actual collision
  simulation-start-hour   ; hour when simulation starts
]

; Define types of agents
breed [matriarchs matriarch]
breed [followers follower]
breed [trains train]
breed [railway-makers railway-maker] ; Helper turtles for railway path creation

turtles-own [
  energy           ; elephant's energy level
  thirst           ; elephant's thirst level
  my-herd          ; the matriarch this elephant follows (for followers)
  age              ; age of the elephant
]

trains-own [
  direction        ; 1 for forward, -1 for backward
  current-path     ; current railway patch the train is on
  target-patch     ; next railway patch to move to
]

patches-own [
  food-value       ; amount of food on this patch
  water-value      ; amount of water on this patch
  max-food-value   ; maximum food a patch can have
  max-water-value  ; maximum water a patch can have
  terrain-type     ; type of terrain (water, grassland, railway, etc.)
  is-railway       ; boolean for whether this patch is part of the railway
  railway-order    ; position in the railway path (for ordered movement)
]

to setup
  clear-all

  ; Set up time tracking
  set simulation-start-hour 6     ; Start at 6 AM
  set model-hour simulation-start-hour
  set model-minute 0
  set ticks-per-minute 5 ; Number of ticks per simulated minute

  ; Initialize tracking
  set proximity-count 0
  set collision-count 0
  set total-elephant-ticks 0
  set proximity-probability 0
  set collision-probability 0

  ; Import background image
  import-pcolors "Screenshot (10).png"

  ; Initialize patch values based on colors
  ask patches [
    set max-food-value 100
    set max-water-value 200
    set is-railway false
    set railway-order 0

    ; Identify railway (orange/brown line)
    ifelse is-orange-or-brown? pcolor [
      set terrain-type "railway"
      set is-railway true
      set food-value 0
      set water-value 0
    ]
    ; Water areas (blue shades)
    [ifelse shade-of? blue pcolor [
      set water-value max-water-value
      set food-value 0
      set terrain-type "water"
    ]
    ; Food areas (green shades)
    [ifelse shade-of? green pcolor [
      set water-value 0
      set food-value max-food-value
      set terrain-type "grassland"
    ]
    ; Other terrain (some food but no water)
    [
      set water-value 0
      set food-value random 30
      set terrain-type "other"
    ]]]
  ]

  ; Set up the railway path
  setup-railway

  ; Create the train
  create-trains 1 [
    set shape "car"
    set color black
    set size 20
    ; Start at the beginning of the railway
    let start-patch min-one-of railway-patches [railway-order]
    move-to start-patch
    set direction 1  ; Start moving forward
    set current-path start-patch
    set target-patch find-next-railway-patch
  ]

  ; Create matriarchs (larger elephants that lead herds)
  create-matriarchs number-of-matriarchs [
    set shape "circle"  ; Using circle for smoother appearance
    set color green
    set size 12
    set energy 100 + random 100
    set thirst 0
    set age 20 + random 30
    move-to one-of patches with [terrain-type != "water" and terrain-type != "railway"]
  ]

  ; Create followers (regular elephants that follow matriarchs)
  create-followers number-of-followers [
    set shape "circle"  ; Using circle for smoother appearance
    set color green - 1
    set size 10
    set energy 100 + random 50
    set thirst 0
    set age 5 + random 20

    ; Assign each follower to a matriarch
    set my-herd one-of matriarchs

    ; Position near their matriarch for more natural initial grouping
    move-to my-herd
    fd 3 + random 3
  ]

  reset-ticks
end

; Helper reporter to identify orange/brown colors for railway
to-report is-orange-or-brown? [color-value]
  ; Extract RGB values
  let r item 0 extract-rgb color-value
  let g item 1 extract-rgb color-value
  let b item 2 extract-rgb color-value

  ; Define orange/brown range
  ; Orange typically has high red, medium green, low blue
  report (r > 150 and g > 80 and g < 180 and b < 100)
end

; Set up the railway path by ordering railway patches
to setup-railway
  ; Get all railway patches
  set railway-patches patches with [is-railway]

  ; If no railway patches found, print a warning
  if not any? railway-patches [
    print "Warning: No orange railway line detected in the image!"
    stop
  ]

  ; Create a temporary turtle to help build the railway path
  create-railway-makers 1 [
    hide-turtle

    ; Find one end of the railway as a starting point
    let ends railway-patches with [count railway-patches in-radius 1.5 <= 3]
    let start-patch one-of ends

    ; If no clear end found, just pick any railway patch
    if start-patch = nobody [
      set start-patch one-of railway-patches
    ]

    ; Move to the starting patch
    move-to start-patch

    ; Order the railway patches to form a path
    let current-patch patch-here
    let ordered-patches (list current-patch)
    ask current-patch [set railway-order 1]

    let path-length 1
    let max-path-length count railway-patches

    ; Build the ordered path iteratively
    while [path-length < max-path-length] [
      ; Find nearby railway patches not yet in the path
      let nearby-patches railway-patches in-radius 1.5 with [not member? self ordered-patches]

      ; If we reach the end of the path
      if not any? nearby-patches [
        ; Try to find any railway patches not yet included
        let remaining-patches railway-patches with [not member? self ordered-patches]
        if not any? remaining-patches [
          ; We've included all railway patches
          print (word "Railway path complete with " path-length " patches")
          die ; Clean up the helper turtle
          stop
        ]
        ; If there are remaining patches but not nearby, teleport to one
        set nearby-patches remaining-patches
      ]

      ; Find the closest neighbor to continue the path
      let next-patch min-one-of nearby-patches [distance myself]
      set path-length path-length + 1
      ask next-patch [set railway-order path-length]
      move-to next-patch
      set current-patch next-patch
      set ordered-patches lput current-patch ordered-patches
    ]

    ; Clean up the helper turtle when done
    die
  ]
end

to-report mouse-patch-coords
  if mouse-inside? [
    report (word [pxcor] of patch mouse-xcor mouse-ycor
            ", " [pycor] of patch mouse-xcor mouse-ycor)
  ]
  report "outside world"
end

to-report current-time
  ; Format the time as HH:MM
  let hour-string (word model-hour)
  if model-hour < 10 [set hour-string (word "0" model-hour)]

  let minute-string (word model-minute)
  if model-minute < 10 [set minute-string (word "0" model-minute)]

  report (word hour-string ":" minute-string)
end

to-report elapsed-time
  ; Calculate total minutes elapsed
  let start-minutes (simulation-start-hour * 60)
  let current-minutes (model-hour * 60 + model-minute)

  ; Handle day rollover
  if current-minutes < start-minutes [
    set current-minutes current-minutes + (24 * 60)
  ]

  let elapsed-minutes (current-minutes - start-minutes)

  ; Format as hours and minutes
  let elapsed-hours floor (elapsed-minutes / 60)
  let remaining-minutes elapsed-minutes mod 60

  report (word elapsed-hours "h " remaining-minutes "m")
end

to-report simulation-progress
  ; Calculate total minutes in simulation
  let total-minutes simulation-duration * 60

  ; Calculate elapsed minutes
  let start-minutes (simulation-start-hour * 60)
  let current-minutes (model-hour * 60 + model-minute)

  ; Handle day rollover
  if current-minutes < start-minutes [
    set current-minutes current-minutes + (24 * 60)
  ]

  let elapsed-minutes (current-minutes - start-minutes)

  ; Calculate percentage
  let progress (elapsed-minutes / total-minutes) * 100

  report precision progress 1
end

to-report is-simulation-complete?
  ; Calculate total minutes in simulation
  let total-minutes simulation-duration * 60

  ; Calculate elapsed minutes
  let start-minutes (simulation-start-hour * 60)
  let current-minutes (model-hour * 60 + model-minute)

  ; Handle day rollover
  if current-minutes < start-minutes [
    set current-minutes current-minutes + (24 * 60)
  ]

  let elapsed-minutes (current-minutes - start-minutes)

  ; Check if we've reached the end
  report elapsed-minutes >= total-minutes
end

to go
  ; Stop when simulation duration is reached
  if is-simulation-complete? [
    print (word "Simulation completed after " elapsed-time)
    stop
  ]

  ; Update model time
  update-model-time

  ; Environment processes
  grow-food-and-water

  ; Move the train
  ask trains [
    move-train
  ]

  ; Update elephant count for probability calculation
  set total-elephant-ticks total-elephant-ticks + count turtles with [breed = matriarchs or breed = followers]

  ; Matriarch behaviors
  ask matriarchs [
    check-train-proximity
    respond-to-train
    matriarch-decide-action
    move-smoothly
    eat-and-drink
    reproduce
    check-death
  ]

  ; Follower behaviors
  ask followers [
    check-train-proximity
    respond-to-train
    follow-matriarch
    eat-and-drink
    reproduce
    check-death
  ]

  ; Update probabilities
  if total-elephant-ticks > 0 [
    set proximity-probability proximity-count / total-elephant-ticks
    set collision-probability collision-count / total-elephant-ticks
  ]

  tick
end

to update-model-time
  ; Increment minute based on ticks
  if ticks mod ticks-per-minute = 0 and ticks > 0 [
    set model-minute model-minute + 1

    ; Handle hour rollover
    if model-minute >= 60 [
      set model-minute 0
      set model-hour model-hour + 1

      ; Handle day rollover
      if model-hour >= 24 [
        set model-hour 0
      ]
    ]
  ]
end

to move-train
  ; Determine how many steps to move based on train speed
  let steps-to-move train-speed

  while [steps-to-move > 0 and target-patch != nobody] [
    face target-patch
    move-to target-patch
    set current-path target-patch
    set target-patch find-next-railway-patch
    set steps-to-move steps-to-move - 1
  ]

  ; If we've reached the end of the line, turn around
  if target-patch = nobody [
    set direction direction * -1
    set target-patch find-next-railway-patch
  ]
end

to-report find-next-railway-patch
  ; Find the next patch in the sequence based on direction
  let current-order [railway-order] of current-path
  let next-order current-order + direction

  ; Find a patch with the next order value
  let next-candidates railway-patches with [railway-order = next-order]

  ; If no next patch, we've reached the end
  if not any? next-candidates [
    report nobody
  ]

  ; Return the next patch
  report one-of next-candidates
end



; Check if elephant is close to a train with more visible indicators
to check-train-proximity
  let nearby-train one-of trains
  if nearby-train != nobody [
    let distance-to-train distance nearby-train

    ; Close approach (proximity)
    if distance-to-train <= 5 and distance-to-train > 2 [
      set proximity-count proximity-count + 1

      ; Much more visible indicator of proximity - longer duration
      set color yellow
      display  ; Force display update
      wait 5  ; Longer pause to make it visible
      set color ifelse-value (breed = followers) [green - 1] [green]
    ]

    ; Actual collision or very close call
    if distance-to-train <= 2 [
      set collision-count collision-count + 1

      ; Much more visible indicator of collision - longer duration and larger
      set color red
      set size size * 1.5  ; Temporarily increase size for visibility
      display  ; Force display update
      wait 5  ; Longer pause to make it visible
      set size size / 1.5  ; Return to normal size
      set color ifelse-value (breed = followers) [green - 1] [green]

      ; Add a small chance the elephant stays traumatized (colored differently)
      if random 5 = 0 [
        ; Some elephants stay partially colored (trauma indicator)
        set color orange - 0.5
      ]
    ]
  ]
end

; Make elephants respond to nearby trains
to respond-to-train
  ; If near a train, move away quickly
  let nearby-train one-of trains in-radius 5
  if nearby-train != nobody [
    ; Elephants get scared and move away from the train
    face nearby-train
    rt 180
    fd elephant-speed * 1.2 ; Faster escape speed
    ; Make scared sounds
    if random 10 < 3 [
      ; We would add sound effects here if NetLogo supported it directly
    ]
  ]
end

to matriarch-decide-action
  ; Matriarchs decide where to lead the herd based on group needs
  ifelse thirst > 50 [
    ; If thirsty, head toward water
    find-water
  ] [
    ifelse energy < 50 [
      ; If hungry, look for food
      find-food
    ] [
      ; Otherwise, random movement with smoothing
      if random 100 < 30 [ rt random-float 90 - 45 ]
    ]
  ]
end

to find-water
  ; Look for water patches nearby
  let water-patches patches in-radius 10 with [water-value > 50]
  if any? water-patches [
    face min-one-of water-patches [distance myself]
    ; Add slight randomization for more natural movement
    rt random-float 10 - 5
  ]
end

to find-food
  ; Look for food patches nearby
  let food-patches patches in-radius 5 with [food-value > 30]
  if any? food-patches [
    face min-one-of food-patches [distance myself]
    ; Add slight randomization for more natural movement
    rt random-float 10 - 5
  ]
end

to follow-matriarch
  ; Followers try to stay near their matriarch but not too close
  if my-herd != nobody [
    ifelse distance my-herd > 5 [
      ; Too far, move closer
      face my-herd
      ; Add small random angle for more natural grouping
      rt random-float 20 - 10
    ] [
      ifelse distance my-herd < 2 [
        ; Too close, move away slightly
        face my-herd
        rt 180
        ; Add small random angle
        rt random-float 30 - 15
      ] [
        ; Good distance, generally follow matriarch's direction
        set heading [heading] of my-herd + random-float 50 - 25
      ]
    ]
  ]

  ; Basic survival - if very hungry or thirsty, prioritize that over following
  if thirst > 80 [ find-water ]
  if energy < 30 [ find-food ]

  move-smoothly
end

to move-smoothly
  ; Smoother movement with slight randomization and energy cost
  fd elephant-speed * (0.3 + random-float 0.2)
  set energy energy - 0.2
  set thirst thirst + 0.3
end

to eat-and-drink
  ; Drink water if on water patch
  if water-value > 0 [
    set thirst max (list 0 (thirst - 20))
    set water-value water-value - 5
    if water-value < 0 [ set water-value 0 ]
  ]

  ; Eat food if available
  if food-value > 0 [
    set energy energy + 10
    set food-value food-value - 10
    if food-value < 0 [ set food-value 0 ]
  ]
end

to grow-food-and-water
  ; Regrow food and water resources
  ask patches [
    ; Water grows back slowly
    if water-value > 0 or terrain-type = "water" [
      set water-value min (list max-water-value (water-value + 1))
    ]

    ; Food grows back on green patches faster
    if terrain-type = "grassland" [
      set food-value min (list max-food-value (food-value + 0.5))
    ]
    ; Other patches grow food more slowly
    if terrain-type = "other" [
      set food-value min (list 30 (food-value + 0.1))
    ]
  ]
end

to reproduce
  ; Only mature elephants can reproduce
  if age < 15 [ stop ]

  ; Random chance of reproduction based on having enough energy
  if energy > 150 and random 1000 < 5 [
    set energy energy - 50

    ; Create a new follower
    hatch-followers 1 [
      set shape "circle"
      set size 5  ; Match the size of other followers
      set energy 100
      set thirst 0
      set age 0

      ; Set the matriarch relationship
      ifelse [breed] of myself = matriarchs [
        ; If parent is a matriarch, follow parent
        set my-herd myself
      ] [
        ; If parent is a follower, follow same matriarch
        set my-herd [my-herd] of myself
      ]

      ; Move slightly away from parent with smooth positioning
      rt random-float 360
      fd 1 + random-float 0.5
    ]
  ]
end

to check-death
  ; Elephants die from old age, starvation, or dehydration
  if age > 60 or energy <= 0 or thirst >= 100 [
    ; If a matriarch dies, followers need to find a new matriarch
    if breed = matriarchs [
      ask followers with [my-herd = myself] [
        set my-herd one-of matriarchs with [self != myself]
      ]
    ]
    die
  ]

  ; Increment age
  set age age + 0.01
end
@#$#@#$#@
GRAPHICS-WINDOW
497
16
1406
626
-1
-1
1.0
1
10
1
1
1
0
1
1
1
-450
450
-300
300
0
0
1
ticks
30.0

BUTTON
101
47
164
80
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
27
48
90
81
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

SLIDER
12
120
185
153
number-of-matriarchs
number-of-matriarchs
0
100
64.0
1
1
NIL
HORIZONTAL

SLIDER
14
171
186
204
number-of-followers
number-of-followers
0
100
50.0
1
1
NIL
HORIZONTAL

MONITOR
26
220
109
265
NIL
current-time
17
1
11

MONITOR
9
280
132
325
Collision probability
precision collision-probability 6
17
1
11

MONITOR
16
332
113
377
Total collisions
collision-count
17
1
11

SLIDER
14
405
186
438
elephant-speed
elephant-speed
0.1
5
4.8
0.1
1
NIL
HORIZONTAL

MONITOR
55
473
161
518
NIL
elapsed-time
17
1
11

MONITOR
17
529
258
574
NIL
word simulation-progress \"% complete\"
17
1
11

SLIDER
49
598
221
631
train-speed
train-speed
1
10
10.0
1
1
NIL
HORIZONTAL

SLIDER
234
631
406
664
simulation-duration
simulation-duration
0.1
24
24.0
0.1
1
NIL
HORIZONTAL

MONITOR
120
345
259
390
NIL
precision proximity-probability 6
17
1
11

MONITOR
143
237
245
282
NIL
proximity-count
17
1
11

@#$#@#$#@
# ELEPHANT-TRAIN COLLISION SIMULATION MODEL

## WHAT IS IT?

This model simulates the interaction between elephant herds and railway trains to study collision scenarios and evaluate potential mitigation strategies. The simulation incorporates realistic elephant social behavior, resource-seeking patterns, and responses to approaching trains. Elephants are organized in herds led by matriarchs, and they move across a landscape seeking food and water while avoiding railway dangers.

The model is designed to help researchers and wildlife managers understand the factors that contribute to elephant-train collisions and test the effectiveness of various prevention strategies.

## HOW IT WORKS

### Agents and Environment

**ELEPHANTS:** The model includes two types of elephants:
- **Matriarchs** (grey circles, size 6): Experienced female leaders who make decisions for their herds based on resource availability and safety
- **Followers** (light grey circles, size 5): Younger elephants who follow their assigned matriarch but may act independently when survival needs are critical

**TRAINS:** Black rectangular agents that move along the railway line at configurable speeds, following a predetermined path based on the orange/brown railway line in the background image.

**ENVIRONMENT:** The landscape is based on an imported image where:
- Blue areas represent water sources
- Green areas represent grasslands with food
- Orange/brown lines represent the railway track
- Other areas provide limited food resources

### Behavioral Rules

**ELEPHANT BEHAVIOR:**
1. **Resource Seeking:** Elephants prioritize water when thirsty (>50 thirst level) and food when hungry (<50 energy level)
2. **Social Structure:** Followers try to stay within 2-5 units of their matriarch while maintaining individual survival needs
3. **Train Avoidance:** When a train comes within 5 units, elephants face away from it and move quickly to safety
4. **Reproduction:** Mature elephants (age >15) with high energy (>150) have a small chance of reproducing
5. **Death:** Elephants die from old age (>60), starvation (energy ≤0), or severe dehydration (thirst ≥100)

**TRAIN BEHAVIOR:**
- Trains follow the railway path in order, moving from patch to patch
- When reaching the end of the line, trains reverse direction
- Train speed is controlled by the simulation speed settings

**ENVIRONMENT DYNAMICS:**
- Food and water resources regenerate over time
- Water sources (blue areas) regenerate to full capacity
- Grasslands regenerate food faster than other terrain types

## HOW TO USE IT

### Setup
1. **Load the background image:** Ensure 'm-w.jpg' is in the same directory as the model file
2. **Set parameters:**
   - `number-of-matriarchs`: Number of herd leaders (recommended: 3-8)
   - `number-of-followers`: Number of follower elephants (recommended: 10-25)
3. **Click SETUP** to initialize the simulation

### Running the Simulation
1. **Click GO** to start the simulation
2. **Monitor outputs:**
   - `current-time`: Shows model time (24-hour format starting at 6:00 AM)
   - `collision-count`: Total number of collision incidents
   - `collision-probability`: Risk per 1000 elephant time-units
   - `mouse-patch-coords`: Shows coordinates when hovering over patches

### Key Controls
- **SETUP:** Initializes the model with current parameter settings
- **GO:** Runs the simulation continuously until stopped or 24-hour cycle completes
- **Speed slider:** Controls simulation speed (affects train movement and time progression)

## THINGS TO NOTICE

### Collision Patterns
- Observe how collision frequency changes with different elephant population sizes
- Notice that collisions often occur near water sources that are close to the railway
- Pay attention to how matriarchs lead their herds away from railway areas when trains approach

### Behavioral Dynamics
- Watch how followers maintain distance from their matriarchs while seeking resources
- Notice the panic response when trains approach - elephants scatter and move erratically
- Observe how resource scarcity forces elephants to take greater risks crossing railway areas

### Population Dynamics
- Monitor population changes due to births and deaths
- Notice how the loss of a matriarch affects follower behavior
- Observe seasonal patterns in movement and resource use

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
NetLogo 6.4.0
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
