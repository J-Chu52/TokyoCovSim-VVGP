extensions[csv]

globals [ ;Global variables
  ;Model result variables
  antibody-rate ;Proportion of the population with antibodies
  total-death ;Total number of deaths
  ;Model control variables
  infect-distance ;Transmission radius
  self-healing-rate ;Probability of self-healing for infected individuals (0-100)
  death-from-vaccination-rate ;Death rate from vaccination (0-1000000)
  two-dose-vaccination-rate ;Proportion of population receiving two doses of vaccine
  daily-new-cases ;Daily new confirmed cases

  daily-immigrant-cases  ;;Daily external cases
  daily-move-out  ;;Daily outbound population migration
  infection-ratio-0.2  ;; Infection probability within radius 0.2
  infection-ratio-0.5  ;; Infection probability within radius 0.2-0.5
  infection-ratio-1.0  ;; Infection probability within radius 0.5-1.0

  student-speed ;;Movement speed of students
  normal-speed  ;;Daily movement speed of non-workers
  death-rate    ;;Fatality rate of infected individuals

  daily-first-dose  ;;Daily number of externally administered first doses of vaccine
  daily-second-dose ;;Daily number of externally administered second doses of vaccine
  daily-third-dose  ;;Daily number of externally administered third doses of vaccine
  daily-fourth-dose ;;Daily number of externally administered fourth doses of vaccine
  daily-tested      ;;Daily number of external tests conducted

  actual-infection-rate
  nominal-infection-rate
]
breed [hospitals hospital]
breed [persons person]

persons-own [ ;Individual properties
  state  ;State (1: uninfected and no antibodies, 2: close contact, 3: infected but not confirmed, 4:infected and confirmed, 5: antibodies after vaccination, 6: antibodies after self-healing, 7: antibodies disappear)
  origin-patch
  occupation-status ;0: unemployed, 1: student, 20: working from home, 21: working in an office
  isolated? ;Is the person isolated?
  vaccination-remain ;Remaining vaccination doses
  vaccince-efficacy-rate ;Vaccine efficacy rate, decreases with days since vaccination
  antibody-efficacy-rate-after-cured ;;Strength of antibodies generated after recovery from infection
  second-dose-interval-days ;Number of days between the first and second vaccine doses
  third-dose-interval-days  ;Number of days between the second and third vaccine doses
  fourth-dose-interval-days ;Number of days between the third and fourth vaccine doses
  after-detection ;Number of days after detection
  infected-days   ;Number of days since infection
  isolated-days   ;Number of days in isolation
  hospitalized?   ;Is the person hospitalized?
  close-contacted-days ;Number of days since close contact

  infect-persons  ;Number of persons infected
]

hospitals-own[
  current-patients
]

to setup ; Button setup calls this function
  clear-all
  csv-inputs-read  ;Load data
  set-global-variable ;Set global variables
  set-population ;Set population
  set-hospital  ;Set hospitals
  set actual-infection-rate []
  set nominal-infection-rate []
  reset-ticks
end

to csv-inputs-read
  file-open "data1.csv"
  let vaccine-inputs []
  set daily-first-dose []
  set daily-second-dose []
  set daily-third-dose []
  set daily-fourth-dose []
  set daily-tested []
  set daily-immigrant-cases []
  set daily-move-out []
  set infection-ratio-0.2 []
  set infection-ratio-0.5 []
  set infection-ratio-1.0 []
  set normal-speed []
  set student-speed []
  set death-rate []
  let skip-first-row 0
  while [not file-at-end?][
    set vaccine-inputs csv:from-row file-read-line
    if skip-first-row > 0[
      set daily-first-dose lput (item 1 vaccine-inputs) daily-first-dose
      set daily-second-dose lput (item 2 vaccine-inputs) daily-second-dose
      set daily-third-dose lput (item 3 vaccine-inputs) daily-third-dose
      set daily-fourth-dose lput (item 4 vaccine-inputs) daily-fourth-dose
      set daily-tested lput (item 5 vaccine-inputs) daily-tested
      set daily-immigrant-cases lput (item 6 vaccine-inputs) daily-immigrant-cases
      set daily-move-out lput (item 7 vaccine-inputs) daily-move-out
      set infection-ratio-0.2 lput (item 8 vaccine-inputs) infection-ratio-0.2
      set infection-ratio-0.5 lput (item 9 vaccine-inputs) infection-ratio-0.5
      set infection-ratio-1.0 lput (item 10 vaccine-inputs) infection-ratio-1.0
      set normal-speed lput (item 11 vaccine-inputs) normal-speed
      set student-speed lput (item 12 vaccine-inputs) student-speed
      set death-rate lput (item 13 vaccine-inputs) death-rate
    ]
    set skip-first-row skip-first-row + 1
     ]
  file-close
end

to set-global-variable ;Set global variables
  set Antibody-rate 0
  set total-death 0
  set infect-distance 1.5
  set self-healing-rate 10
  set daily-new-cases 0
end

to set-population ;Set up population
  create-persons initial-population [ ;Initialize all populations and attributes
    setxy random-xcor random-ycor
    set origin-patch patch-here
    set occupation-status 0
    set shape "person"
    set size 2
    set color green
    set state 1
    set isolated? false
    set hospitalized? false
    set vaccination-remain 2
    set second-dose-interval-days random 22 + 35 ;Randomly initialize the interval between the first and second doses for each person, at least three weeks and not exceeding eight weeks
    set infect-persons 0
    set after-detection 8 ;Initialize the number of days after detection, greater than 7 can be tested at any time
  ]
  ask n-of (student-rate / 100 * initial-population) persons[set occupation-status 1]
  ask n-of (labor-force-participation-rate / 100 * initial-population) persons with [occupation-status = 0][
    ifelse random 100 < work-from-home-rate
    [set occupation-status 20]
    [set occupation-status 21 set shape "person business"]]
  ask n-of initial-infected-population persons [ ;Initialize infected individuals
    set color blue
    set state 3
    set isolated? false
    set infected-days 0
  ]

  ask n-of (initial-infected-population * initial-confirmation-rate / 100) persons with [state = 3][ ;Initialize confirmed patients
    set color red
    set state 4
    set isolated? true
    set infected-days random 28
  ]
end

to set-hospital
  create-hospitals 1 [
    set current-patients 0
    set shape "house"
    set size 10
    set color yellow
    move-to patch 999 499]
end

to go ; Button go calls this function
  set daily-new-cases 0
  import-unconfirmed-cases
  ;Assume people can go out for 8 hours each day
  repeat 8[
    people-move ;People movement
    infect-others ;Infection
  ]
  ;All individuals return to their origin patch
  ask persons[move-to origin-patch]

  self-healing ;Self-healing
  death-from-illness ;Death from illness
  get-vaccination ;Vaccination
  virus-detection ;Virus detection
  isolation-treatment ;Isolation treatment
  vaccine-efficacy-update ;Update vaccine efficacy status
  calculate-global-variables ;Calculate global varibales


  ;Close contacts who remain uninfected after 21 days are restored to uninfected
  ask persons with [state = 2][
    set close-contacted-days close-contacted-days - 1
    if close-contacted-days <= 0 [
      set state 1]]

  ;Random individuals leaving
  ask n-of (item ticks daily-move-out) persons[die]

  tick
  if ticks > length daily-immigrant-cases - 1[stop]

end


to import-unconfirmed-cases
   create-persons (item ticks daily-immigrant-cases)
  [ setxy random-xcor random-ycor
    set origin-patch patch-here
    set shape "person"
    set color Blue
    set state 3
    set infect-persons 0
    ifelse (random 100) < labor-force-participation-rate
    [ifelse (random 100) < work-from-home-rate
      [set occupation-status 20 set shape "person business"]
      [set occupation-status 21 set shape "person business"]] ;Determine whether the current individual is employed or not
    [ifelse (random 100) < student-rate
      [set occupation-status 1]
      [set occupation-status 0]]
    set isolated? false
    set hospitalized? false
    set vaccination-remain 2
    set after-detection 8 ;Initialize the number of days after detection, individuals can undergo testing at any time if the value is greater than 7
  ]
end

to people-move ;Population move
  let normalspeed item ticks normal-speed
  let studentspeed item ticks student-speed
  ask persons with [not isolated?] [ ;for those not isolated
    rt random 60
    lt random 60

    if occupation-status = 1[fd studentspeed]
    if occupation-status = 21[fd normalspeed * 1.5]
    if occupation-status = 0 or occupation-status = 20 [fd normalspeed]

    boundary-back ;Boundary return based on terrain
  ]
end

to boundary-back ;Boundary return based on terrain
  if xcor >= max-pxcor - 1 or xcor <= min-pxcor + 1 or ycor >= max-pycor - 1 or ycor <= min-pycor + 1 [
    rt 180
  ]
end

to infect-others ;Infection

  ask persons with [state = 3] [ ; For the infected population (infected but not confirmed)
    if not isolated? [ ;for those not isolated
      let me self
      ask persons with [state = 1 or state = 7] [ ;Infect individuals without infection or antibodies within the transmission radius
        let dis distance me
        ifelse dis <= 0.2 and random-float 1 < item ticks infection-ratio-0.2  ;;Radius[0,0.2]
        [infected set infect-persons infect-persons + 1]
        [ifelse dis > 0.2 and dis <= 0.5  ;Radius(0.2,0.5]
          [set state 2
            set close-contacted-days 21
            set color violet
            if (random-float 1) < (item ticks infection-ratio-0.5) [infected set infect-persons infect-persons + 1]]
          [if dis > 0.5 and dis <= 1.0[
            set close-contacted-days 21
            set state 2  ;Radius(0.5,1.0]
            set color violet
            if (random-float 1) < (item ticks infection-ratio-1.0) [infected set infect-persons infect-persons + 1]]]]
      ]
    ]
  ]
end

to infected ;Infected with COVID

  set state 3
  set color blue
  set infected-days 0
end

to self-healing ;Self-heal
  ask persons with [state = 3 or state = 4] [ ;For those infected
    set infected-days infected-days + 1 ;Update the number of days since infection
    if infected-days > 28 and not isolated? [ ;For those who have been infected more than 48 dyas and not quarantined
      let random-num random 100
      if random-num < self-healing-rate [
        set state 6
        if infect-persons > 0 [set actual-infection-rate lput infect-persons actual-infection-rate]
        set antibody-efficacy-rate-after-cured initial-antibody-titer-after-cured ;Generate antibody after self-healing
        set color yellow
        set isolated? false
      ]
    ]
  ]
end

to death-from-illness ;Die from illnesses
  let die-rate item ticks death-rate
  ask persons with [state = 3 or state = 4] [
    let random-num random 100000
    if random-num < die-rate and hospitalized? = false[
      set total-death total-death + 1
      die
    ]
  ]
end

to isolation-treatment ;Quarantine treatment
  ask persons with [state = 4 and isolated?] [ ;For individuals currently undergoing isolation treatment
    set isolated-days isolated-days + 1
    if isolated-days > 28 [ ;If treatment exceeds 28 days and the patient is still alive, they are discharged and develop antibodies
      set state 6
      if infect-persons > 0 [set actual-infection-rate lput infect-persons actual-infection-rate]
      set antibody-efficacy-rate-after-cured initial-antibody-titer-after-cured
      set color yellow
      set isolated? false
      if hospitalized?[  ;If the isolated person is receiving treatment at a hospital
        ask hospitals[set current-patients current-patients - 1]
        move-to one-of other patches with [any? persons-here = false]
        set hospitalized? false]
    ]
  ]
end

to get-vaccination ;Vaccination
  let remain-num item ticks daily-second-dose
  ask persons with [vaccination-remain = 1 and second-dose-interval-days = 0] [ ;Prioritize individuals needing the second dose
    if remain-num > 0 [ ;If there are remaining vaccines
      set vaccination-remain 0
      let random-num random 100
      if random-num < average-second-dose-efficacy [ ;Probability of developing antibodies after the second dose
        set state 5
        if infect-persons > 0 [set actual-infection-rate lput infect-persons actual-infection-rate]
        set vaccince-efficacy-rate initial-antibody-titer-after-two-dose
        set color yellow
        set third-dose-interval-days 1
      ]
      set remain-num remain-num - 1
    ]
  ]

   ;;Forth dose
  let fourthpersons persons with [vaccination-remain = -1 and fourth-dose-interval-days > 150] ;Can receive the fourth dose after 150 days of receiving the third dose
    if count fourthpersons > 0[
      ifelse count fourthpersons >  item ticks daily-fourth-dose[
      ask max-n-of (item ticks daily-fourth-dose)  fourthpersons [fourth-dose-interval-days][
        set state 5
        if infect-persons > 0 [set actual-infection-rate lput infect-persons actual-infection-rate]
          set vaccince-efficacy-rate initial-antibody-titer-after-four-dose
          set vaccination-remain -2
          set color yellow]][
        ask max-n-of (count fourthpersons)  fourthpersons [fourth-dose-interval-days][
          set vaccince-efficacy-rate initial-antibody-titer-after-two-dose
          set vaccination-remain -2
          set color yellow]]]


  ;;Third dose
  let thirddpersons persons with [vaccination-remain = 0 and third-dose-interval-days > 180] ;Can receive the fourth dose after 150 days of receiving the third dose
    if count thirddpersons > 0[
      ifelse count thirddpersons >  item ticks daily-third-dose[
      ask max-n-of (item ticks daily-third-dose)  thirddpersons [third-dose-interval-days][
        set state 5
        if infect-persons > 0 [set actual-infection-rate lput infect-persons actual-infection-rate]
          set vaccince-efficacy-rate initial-antibody-titer-after-three-dose
          set vaccination-remain -1
          set fourth-dose-interval-days 1

          set color yellow]][
        ask max-n-of (count thirddpersons)  thirddpersons [third-dose-interval-days][
          set vaccince-efficacy-rate initial-antibody-titer-after-two-dose
          set vaccination-remain -1
          set fourth-dose-interval-days 1
          set color yellow]]]

  ask persons with [vaccination-remain = 1 and second-dose-interval-days > 0] [ ;Countdown the interval for individuals who have received the first dose but not the second dose
    set second-dose-interval-days second-dose-interval-days - 1
  ]
  ask persons with [vaccination-remain = 0 and third-dose-interval-days > 0] [  ;Countdown the interval for individuals who have received the second dose but not the third dose
    set third-dose-interval-days third-dose-interval-days + 1
  ]
  ask persons with [vaccination-remain = -1 and fourth-dose-interval-days > 0] [ ;Countdown the interval for individuals who have received the third dose but not the fourth dose
    set fourth-dose-interval-days fourth-dose-interval-days + 1
  ]


  ;;First dose
  set remain-num item ticks daily-first-dose
  if remain-num > 0 [ ;If there are remaining vaccines
    let pre-vaccination-persons persons with [vaccination-remain = 2] ;Remaining vaccines for the first dose
    ifelse remain-num < count pre-vaccination-persons [ ;If the number of eligible persons is greater than the remaining vaccination capacity, vaccinate based on remaining vaccines
      ask n-of remain-num pre-vaccination-persons [
        vaccination
      ]
    ] [ ;; If the number of eligible persons is less than the remaining vaccination capacity, vaccinate all remaining persons
      ask pre-vaccination-persons [
        vaccination
      ]
    ]
  ]
end

to vaccination ;Vaccination
  set vaccination-remain 1
  let random-num random 1000000
  if random-num < death-from-vaccination-rate [ ;Death from vaccination
    set total-death total-death + 1
    die
  ]
  set random-num random 100
  if random-num < average-first-dose-efficacy [ ;Probability of developing antibodies after the first dose
    set second-dose-interval-days random 22 + 29 ;Randomly initialize the interval between the first and second doses for each person, at least three weeks and not exceeding eight weeks
    set vaccination-remain 1
    set state 5
    if infect-persons > 0 [set actual-infection-rate lput infect-persons actual-infection-rate]
    set vaccince-efficacy-rate 4160
    set color yellow
  ]
end

to virus-detection ;Virus detection
  let test-num item ticks daily-tested
  if test-num >= 0 [
    let pre-test-persons persons with [color = violet or color = blue] ;Prioritize the testing of individuals who are most likely to be infected
    if any? pre-test-persons[
      ifelse test-num <= count pre-test-persons [
        ask n-of test-num pre-test-persons [detection]]
      [ ;Test other individuals except those in isolation
      ask n-of (test-num - count pre-test-persons) persons with [state != 4] [detection] ;Test other individuals except those in isolation
  ]
    ]


  ]
  ask persons [set after-detection after-detection + 1]
end

to detection ;Detect infection
  set after-detection 0 ;Reset the number of days after detection
  if state = 3 [ ;Detect infected patients and proceed with isolation treatment
    set daily-new-cases daily-new-cases + 1
    set state 4
    if infect-persons > 0 [set nominal-infection-rate lput infect-persons nominal-infection-rate]
    set color red
    set isolated? true
    set isolated-days 0

    if sum [hospital-capacity - current-patients] of hospitals > 0[
      ask hospitals[set current-patients current-patients + 1]
      set hospitalized? true
      move-to patch 0 0
    ]
  ]
end


to vaccine-efficacy-update ;;Update vaccine efficacy
  ask persons with [state = 5 and vaccination-remain = 0][
    set vaccince-efficacy-rate vaccince-efficacy-rate * antibody-decline-for-vaccinated ;;The level of antibodies decreases as the number of days increases.
    if vaccince-efficacy-rate < vaccine-efficacy-threshold[ ;;When the level of antibodies in the body decreases to a certain threshold, it is considered that the person's antibodies have disappeared.
      set vaccince-efficacy-rate 0
      set color green
      set state 7]
  ]
  ask persons with [state = 6][
    set antibody-efficacy-rate-after-cured antibody-efficacy-rate-after-cured * antibody-decline-for-cured
    if antibody-efficacy-rate-after-cured < vaccine-efficacy-threshold[ ;;When the level of antibodies in the body decreases to a certain threshold, it is considered that the person's antibodies have disappeared.
      set antibody-efficacy-rate-after-cured 0
      set color green
      set state 7]
  ]
end

to calculate-global-variables ;Calculate global variables
  ;Antibody-rate
  let antibody-num count persons with [state = 5 or state = 6]
  let total-num count persons
  set antibody-rate 100 * antibody-num / initial-population
  let two-dose-vaccination-num count persons with [vaccination-remain = 0]
  set two-dose-vaccination-rate 100 * two-dose-vaccination-num / initial-population
end
@#$#@#$#@
GRAPHICS-WINDOW
10
642
2018
1651
-1
-1
1.0
1
10
1
1
1
0
0
0
1
0
1999
0
999
1
1
1
Days
30.0

SLIDER
9
10
364
43
initial-population
initial-population
0
30000
12527.0
1
1
NIL
HORIZONTAL

BUTTON
9
157
70
194
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
79
157
134
194
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

MONITOR
1552
382
1679
427
Antibody-rate%
precision antibody-rate 2
17
1
11

SLIDER
9
299
363
332
average-first-dose-efficacy
average-first-dose-efficacy
0
100
52.0
1
1
%
HORIZONTAL

SLIDER
9
336
363
369
average-second-dose-efficacy
average-second-dose-efficacy
0
100
91.0
1
1
%
HORIZONTAL

SLIDER
9
47
364
80
initial-infected-population
initial-infected-population
0
150
0.0
1
1
NIL
HORIZONTAL

PLOT
368
15
836
325
Vaccination and Antibody
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Antibody" 1.0 0 -1184463 true "" "plot count persons with [state = 5 or state =  6]"
"1st-dose" 1.0 0 -6759204 true "" "plot count persons with [vaccination-remain = 1 or vaccination-remain = 0 or vaccination-remain = -1 or vaccination-remain = -2]"
"2nd-dose" 1.0 0 -11033397 true "" "plot count persons with [vaccination-remain = 0 or vaccination-remain = -1 or vaccination-remain = -2]"
"3rd-dose" 1.0 0 -14985354 true "" "plot count persons with [vaccination-remain = -1 or vaccination-remain = -2]"
"4th-dose" 1.0 0 -7500403 true "" "plot count persons with [vaccination-remain = -2]"

MONITOR
1325
380
1434
425
total-death
total-death
17
1
11

SLIDER
9
197
364
230
labor-force-participation-rate
labor-force-participation-rate
0
100
62.0
1
1
%
HORIZONTAL

SLIDER
12
506
366
539
antibody-decline-for-vaccinated
antibody-decline-for-vaccinated
0.98
1
0.980916
0.000001
1
NIL
HORIZONTAL

SLIDER
13
579
367
612
vaccine-efficacy-threshold
vaccine-efficacy-threshold
0
500
250.0
1
1
AU/mL
HORIZONTAL

MONITOR
1325
329
1392
374
COVID-
count persons with [state = 1] + count persons with [state = 7]
17
1
11

MONITOR
1395
329
1465
374
COVID?
count persons with [state = 2]
17
1
11

MONITOR
1468
329
1538
374
COVID(+)
count persons with [state = 3]
17
1
11

MONITOR
1542
329
1607
374
COVID+
count persons with [state = 4]
17
1
11

SLIDER
9
83
365
116
initial-confirmation-rate
initial-confirmation-rate
0
100
0.0
1
1
%
HORIZONTAL

PLOT
370
325
835
623
Infection and confirmed
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"COVID?" 1.0 0 -11783835 true "" "plot count persons with [state = 2]"
"COVID(+)" 1.0 0 -13345367 true "" "plot count persons with [state = 3]"
"COVID+" 1.0 0 -5298144 true "" "plot count persons with [state = 4]"

MONITOR
1415
486
1505
531
2nd-dose%
(count persons - count persons with [vaccination-remain = 1] - count persons with [vaccination-remain = 2]) / initial-population * 100
2
1
11

PLOT
836
325
1321
623
COVID +
NIL
NIL
0.0
1.0
0.0
1.0
true
true
"" ""
PENS
"Daily new" 1.0 0 -1604481 true "" "plot daily-new-cases"

SLIDER
13
543
367
576
antibody-decline-for-cured
antibody-decline-for-cured
0.98
1
0.99864
0.000001
1
NIL
HORIZONTAL

SLIDER
9
120
365
153
hospital-capacity
hospital-capacity
0
20
6.0
1
1
NIL
HORIZONTAL

MONITOR
1442
382
1548
427
Hospitalized
count persons with [hospitalized? = true]
17
1
11

MONITOR
1612
329
1687
374
Daily new
daily-new-cases
17
1
11

SLIDER
9
369
363
402
initial-antibody-titer-after-two-dose
initial-antibody-titer-after-two-dose
0
4000
1629.0
1
1
NIL
HORIZONTAL

SLIDER
12
475
366
508
initial-antibody-titer-after-cured
initial-antibody-titer-after-cured
0
500
357.0
1
1
NIL
HORIZONTAL

MONITOR
1328
433
1548
478
Population Density(person/patch)
precision ((count turtles) / (count patches)) 7
7
1
11

MONITOR
1552
433
1680
478
total population
count persons
17
1
11

TEXTBOX
1505
606
1889
634
Note: simulation start from Jan 24, 2020, till May 8, 2023
11
0.0
0

SLIDER
9
263
363
296
work-from-home-rate
work-from-home-rate
0
100
30.0
1
1
%
HORIZONTAL

MONITOR
1425
536
1504
581
Telework
count persons with [occupation-status = 20]
17
1
11

MONITOR
1510
486
1592
531
3rd-dose%
100 * (count persons with [vaccination-remain = -1])/ initial-population
2
1
11

MONITOR
1328
483
1411
528
1st-dose%
100 * (count persons - count persons with [vaccination-remain = 2])/ initial-population
2
1
11

SLIDER
9
230
364
263
student-rate
student-rate
0
100
17.0
1
1
%
HORIZONTAL

MONITOR
1512
536
1586
581
students
count persons with [occupation-status = 1]
17
1
11

MONITOR
1595
536
1682
581
unemployed
count persons with [occupation-status = 0]
17
1
11

MONITOR
1328
536
1420
581
work in office
count persons with [occupation-status = 21]
17
1
11

MONITOR
1599
486
1683
531
4th-dose%
100 * (count persons with [vaccination-remain = -2])/ initial-population
17
1
11

PLOT
836
15
1322
325
Average Infect (RO)
NIL
person
0.0
2.0
0.0
2.0
true
true
"" ""
PENS
"Actual" 1.0 0 -5298144 true "" "carefully [if ticks > 0 [plot mean actual-infection-rate]][plot 0]"
"Nominal" 1.0 0 -16449023 true "" "carefully [if ticks > 0[plot mean nominal-infection-rate]][plot 0]"

PLOT
1323
15
1778
324
Covid-
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Covid-" 1.0 0 -14439633 true "" "plot count persons with [state = 1] + count persons with [state = 7]"
"People" 1.0 0 -7500403 true "" "plot count persons"

SLIDER
12
407
366
440
initial-antibody-titer-after-three-dose
initial-antibody-titer-after-three-dose
0
4000
3419.0
1
1
NIL
HORIZONTAL

SLIDER
12
440
366
473
initial-antibody-titer-after-four-dose
initial-antibody-titer-after-four-dose
0
4000
3655.0
1
1
NIL
HORIZONTAL

MONITOR
1328
583
1472
628
Average Infect Persons
mean [infect-persons] of persons with [infect-persons > 0]
17
1
11

@#$#@#$#@
## What is it?

This model builds a Tokyo-based down-scaled simulation environment to explain the eight epidemic trends using agent-based modelling and extended SEIR denotation. Four key factors are being considered, that are 1. vaccination, 2. virus mutation, 3. government policy and 4. PCR test. Simulation period is 2020.01.24 ~ 2023.05.08. 


## How it works?

This model reads an external csv file called 'data1.csv', import information related to the four key factors, conduct simulation, output plots and key numbers at each time step.


## How to use it?

Use it in conjuction with the 'data1.csv' file. click 'setup' then click 'go' in the interface. In order to obtain the results faster, it is recommended to unclick 'view updates' so that the simulation speed shall improve dramatically.


## Things to notice

It is noticed that the number of vaccinated agents in 'Vaccination and Antibody' plot  drop during the later period of simulation because this model considers population movements, both inbound and outbound. Some may move out of Tokyo after receiving vaccinations. 



## Things to try

Readers may compare the simulated results obtained from 'COVID+' plot and the scaled infection cases of Tokyo (population in this model : population of Tokyo Metropolitan Area = 12,527:13,920,000 approximately). 

Readers may also try to scale up and down to check the model's stability and verify the feasibility of linear scaling. To do so, readers should change all together the followings: the initial population / simulation environment / hospital capacity and the doses of vaccination/ PCR tests, inbound/outbound population.

Besides, readers are encouraged to modifty the model to reproduce regional COVID-19 epidemic trends, given that data have been correctly collected and regional circumstances have been fully considered.



## Extending the model

Currently this model does not consider the work-from-home rate of Tokyo citizens. But readers may try to complete the function to study the impact of WFH policy during Coronavirus outbreak. 


## Related models
The HIV model in the models library has inspired me to develop into the current TokyoCovSim-VVGP model.
 

## Credits and references
There are two papers related to this model. 
1. Simulation of SARS-CoV-2 epidemic trends in Tokyo considering vaccinations, virus mutations, government policies and PCR tests written by Jianing Chu, Hikaru Morikawa, Yu Chen.
2. Evaluating the Multifactorial Effects on SARS-CoV-2 Spread in Tokyo Metropolitan Area with an Agent-based Model written by Jianing Chu and Yu Chen.


## Acknowledgement
This model would not have been possible without the support from a number of important individuals. First and foremost, I am grateful to Dr. Zhiyi Zhang from INSA Lyon for his invaluable support and insightful discussin during the global pandemic. His sharing of relevant articles and simulation results greatly inspired me to develop this research. I also thank M.D. Ariel Israel for his inspiring paper about IgG titer regression and feedback about my constructed model. I also thank my families Aiguo Chu, Yun Liu and Xiaomi Chu, Yicheng Xiao as well as my instructor Dr. Prof Yu Chen. I would like to express my gratitude to the WINGS-CFS Program and the Japan Society for the Promotion of Science for providing research funding. Last but not the least, hope that complex system simulation can save the world. El Psy Congroo!


## Contact
Jianing Chu (Sonata)
1st yr PhD Student @ UTokyo as of 03/2024
j-chu@g.ecc.u-tokyo.ac.jp
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

person business
false
0
Rectangle -1 true false 120 90 180 180
Polygon -13345367 true false 135 90 150 105 135 180 150 195 165 180 150 105 165 90
Polygon -7500403 true true 120 90 105 90 60 195 90 210 116 154 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 183 153 210 210 240 195 195 90 180 90 150 165
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 76 172 91
Line -16777216 false 172 90 161 94
Line -16777216 false 128 90 139 94
Polygon -13345367 true false 195 225 195 300 270 270 270 195
Rectangle -13791810 true false 180 225 195 300
Polygon -14835848 true false 180 226 195 226 270 196 255 196
Polygon -13345367 true false 209 202 209 216 244 202 243 188
Line -16777216 false 180 90 150 165
Line -16777216 false 120 90 150 165

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
NetLogo 6.3.0
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
