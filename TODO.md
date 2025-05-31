# TODO.md

## Cleanup

Analyze `llms.txt`, and analyze and revise `PLAN.md`: 

  - Rewrite `README.md` to include extensive documentation that explains exactly how the app works technically, and how to use it. 

  - From `PLAN.md`, completely remove things that are done. 

## v2.0 Rewrite

Currently, the app slows down the mouse pointer by a customizable multiplier when I hold `fn` key. 

We want the following UI elements in the widget: 

The widget should have a width so that inside a horizontal slider should fit perfectly that is precisely 400 px wide  

Section 1: Slow speed

- "Slow speed" slider should be 400 px wide, which is 100%. The pointer slowdown should be expressed by the % of the normal distance the pointer travels. So if the slider is at 50%, then it’s basically "2" in the older UI. 

- The "Slow move" button set lets me choose the modifiers that temporarily activate the slow speed: a series of "fn", "ctrl", "opt", "cmd" buttons, and the user can choose which ones are the modifier combo that activates slow move.

Setion 2: Drag acceleration

When I start dragging (that is, I press-and-hold the button and I start moving the pointer), our app should modify the pointer speed based on the combo of "Slow speed" slider and "Drag acceleration" slider. 

The "Drag acceleration" slider should also be 400 px wide, which is actually 400 px. This slider controls the "acceleration radius" of the pointer. 

So when I start dragging, the pointer speed is the "Slow speed" (customized % of normal speed) but if I have dragged for the distance specified by the "Drag acceleration" slider, then the pointer speed catches up to the normal speed. The acceleration is non-linear, such that near the start of the drag, the pointer speed increases slowly, but as I drag further, the pointer speed increases faster. 

Finally, a Quit button on the right. 

Think of a very good a logical UI for it. Think and re-think the above design, think of a good structure. The UI should also be minimal and compact, clear without much on-screen text and clutter. 

---

Now: Think about all the instructions above, and then adjust the `PLAN.md` document. Remove all items that are "done", and then write a detailed spec for a junior dev that outlines exactly how the rewrite needs to be done. Include annotated code samples, include rationale. Don't actually write any code yet, just review, revise, think, double-check, review, revise again — all inside the `PLAN.md` document. 