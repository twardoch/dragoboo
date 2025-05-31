# Dragoboo

Dragoboo has a solid foundation with the core architecture, SwiftUI interface, and basic event tap functionality implemented. The main challenge is: 

The app has good UI, it works on the surface, but the core functionality is not working at all, because when I hold `fn`, the cursor movement does NOT slow down as expected. It seems that macOS somehow completely ignores the event tap modifications, or the modifications are not being applied correctly. 

1. Read the current codebase of Dragoboo from `llms.txt`

2. Read the research on `_private/research.md` that discusses alternative ways to modify the cursor speed when `fn` is held. 

3. In `PLAN.md`, write a plan for how to fix the core functionality. This plan must be a detailed explanation to a junior software dev who is not familiar with the codebase. Write step-by-step instructions, be specific, include all the details and annotated code changes. 