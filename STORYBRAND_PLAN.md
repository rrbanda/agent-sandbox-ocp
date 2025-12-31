# StoryBrand Transformation Plan

## Overview

This document outlines the plan to restructure the Securing Code First Agents on OpenShift workshop using Donald Miller's **StoryBrand 7-Part Framework** to create a more engaging, memorable, and effective learning experience.

---

## Part 1: The StoryBrand Framework Applied

### The 7 Elements

| # | Element | In Our Workshop |
|---|---------|-----------------|
| 1 | **A Character** | The workshop participant (Agent Developer or Platform Admin) |
| 2 | **Has a Problem** | AI agents are powerful but dangerous without proper security |
| 3 | **Meets a Guide** | This workshop + OpenShift platform |
| 4 | **Who Gives Them a Plan** | The 4-part ADLC-based structure |
| 5 | **And Calls Them to Action** | "Deploy a secured Currency Agent" |
| 6 | **That Helps Them Avoid Failure** | Container escapes, data breaches, compliance violations |
| 7 | **And Ends in Success** | Production-ready, secure AI agent with full observability |

### The Three Levels of Problem

Miller emphasizes that effective storytelling addresses **three levels of problems**:

| Level | General | Our Workshop |
|-------|---------|--------------|
| **External** | The surface-level problem | "AI agents can escape containers, exfiltrate data, and take unauthorized actions" |
| **Internal** | How it makes them feel | "I don't know if my agent deployment is actually secure" / "I'm worried I'll be responsible for a breach" |
| **Philosophical** | Why it matters to the world | "AI should empower organizations, not expose them to new risks" |

---

## Part 2: Current State Analysis

### What's Working Well

1. **Clear structure** - 4 parts, logical progression
2. **Good technical depth** - Defense in depth is well explained
3. **Persona-based guidance** - Clear who should do what
4. **Practical example** - Currency Agent is concrete and understandable

### What Could Be Improved

1. **Opening lacks emotional hook** - Jumps straight to "what you'll build"
2. **Problem isn't personalized** - Written as abstract threats, not "your" problem
3. **Guide positioning is implicit** - Workshop doesn't clearly position itself as the trusted guide
4. **Stakes aren't visceral** - "Container escape" is technical, not emotional
5. **Success vision is technical** - Needs transformation language
6. **No recurring narrative thread** - Each section feels standalone

---

## Part 3: Transformation Plan

### Phase 1: Workshop Landing Page (`docs/workshop/index.md`)

**Current Opening:**
```markdown
# Securing Code First Agents on OpenShift on OpenShift
A hands-on workshop for securing AI agents...
```

**Proposed Opening (StoryBrand):**
```markdown
# Securing Code First Agents on OpenShift on OpenShift

## You've Built an AI Agent. Now What?

Your agent can convert currencies, answer questions, automate workflows. 
It's impressive. It's powerful. And it's a security risk you might not fully understand yet.

**Here's what keeps agent developers up at night:**

- *"What if my agent generates code that escapes its container?"*
- *"What if a prompt injection tricks it into leaking customer data?"*
- *"What if it calls an API it shouldn't—and I'm responsible?"*

These aren't hypotheticals. They're the new reality of agentic AI.

**The good news?** There's a proven approach to deploy agents safely—and this workshop teaches you how.
```

### Phase 2: Establish the Guide

After the opening, establish credibility and empathy:

```markdown
## Why This Workshop Exists

We've seen organizations rush to deploy AI agents—only to discover too late 
that traditional container security doesn't work for systems that can:
- Generate and execute code at runtime
- Make autonomous decisions about which APIs to call
- Be manipulated through natural language prompts

This workshop is built on **battle-tested OpenShift technologies**:
- Kata Containers (VM isolation at the kernel level)
- Istio Service Mesh (network egress control)
- Kuadrant + OPA (policy enforcement before execution)

We'll guide you through deploying a real agent with all three protection layers.
```

### Phase 3: Present the Plan (Simplified)

Miller recommends **3-4 steps max** for clarity:

```markdown
## The Path to Secure Agent Deployment

| Step | What You'll Do | Outcome |
|------|----------------|---------|
| **1. Understand** | Learn why agents need special security | Clarity on the threat model |
| **2. Build** | Develop and test your agent | Working Currency Agent |
| **3. Secure** | Deploy with defense in depth | Production-ready protection |
| **4. Verify** | Test that security actually works | Confidence it's locked down |
```

### Phase 4: Call to Action

Clear, direct, singular:

```markdown
## Start Now

By the end of this workshop, you'll deploy a Currency Agent that:
-  Converts USD to EUR (and works correctly)
-  Refuses cryptocurrency conversions (policy enforced)
- 🔒 Can't escape its VM (even if compromised)
- 📊 Has full observability (you can see everything)

**Time required:** ~2 hours

👉 **[Begin the Workshop](01-foundations/index.md)**
```

### Phase 5: Stakes (Failure and Success)

Add a clear "failure" section that makes stakes visceral:

```markdown
## What's at Stake

### Without Proper Security

| Scenario | Impact |
|----------|--------|
| Container escape | Attacker gains access to host node, other workloads |
| Data exfiltration | Customer data sent to unauthorized endpoints |
| Unauthorized tool usage | Financial transactions, compliance violations |
| No visibility | You won't know until it's too late |

### With This Approach

| Protection | Reality |
|------------|---------|
| VM Isolation | Even a kernel exploit stays contained |
| Egress Control | Only approved APIs are reachable |
| Tool Policies | Every action is validated first |
| Full Traces | Complete visibility into agent behavior |
```

---

## Part 4: Narrative Thread for Each Section

Each Part should open with a story beat:

### Part 1: Foundations
**Story Beat:** *"Before you can solve a problem, you need to understand it."*

Opening: "AI agents aren't just chatbots. They take actions. And that changes everything about how you need to think about security..."

### Part 2: Inner Loop
**Story Beat:** *"Start small. Iterate fast. Prove it works."*

Opening: "Before worrying about production security, let's make sure your agent actually does what you want. The inner loop is where you develop and test rapidly..."

### Part 3: Outer Loop
**Story Beat:** *"Now we make it real. And make it safe."*

Opening: "Your agent works. Now it's time to deploy it properly—with the security layers that will let you sleep at night..."

### Part 4: Reference
**Story Beat:** *"Everything you need, when you need it."*

Opening: "Stuck? Need details? This reference section has you covered..."

---

## Part 5: Recurring Motifs

Create consistency with recurring elements:

### The Currency Agent as Protagonist

Make the Currency Agent a character in the story:
- "Meet the Currency Agent—it converts currencies using real-time rates"
- "The Currency Agent wants to be helpful. But without guardrails, 'helpful' can become 'harmful'"
- "By the end, your Currency Agent will be secure, compliant, and observable"

### The "Before and After" Contrast

Use Nancy Duarte's technique at key moments:

| Before | After |
|--------|-------|
| Agent runs in regular container | Agent runs in Kata VM |
| Can call any external API | Can only call approved APIs |
| No visibility into decisions | Complete trace of every action |
| "I hope it's secure" | "I can prove it's secure" |

### The Three Layers as Protection Metaphor

Use consistent visual language:
- Layer 1 (VM): "The vault" - even if someone breaks in, they can't get out
- Layer 2 (Network): "The checkpoint" - controls what goes in and out
- Layer 3 (Policy): "The rules" - validates every action before execution

---

## Part 6: Implementation Order

### Step 1: Rewrite `docs/workshop/index.md`
- Add emotional opening (the problem)
- Position workshop as guide
- Simplify the plan to 4 clear steps
- Add stakes section (failure/success)
- Strong call to action

### Step 2: Add story beats to Part introductions
- `01-foundations/index.md` - "Understand the problem"
- `02-inner-loop/index.md` - "Prove it works"
- `03-outer-loop/index.md` - "Make it safe"
- `04-reference/index.md` - "Get help when you need it"

### Step 3: Enhance `01-why-agents-need-security.md`
- Make examples more visceral
- Add internal/philosophical problem levels
- Connect to reader's likely anxieties

### Step 4: Add "transformation" language throughout
- Before/after contrasts at key milestones
- "By completing this step, you now have..."
- Progress indicators that feel like achievements

### Step 5: Strengthen conclusions
- Each section ends with clear "what you've accomplished"
- Preview of "what's next" that creates anticipation
- Reinforce the success vision

---

## Part 7: Tone and Voice Guidelines

### Current Tone
- Technical, informative
- Third-person or impersonal
- Focuses on what things *are*

### Target Tone
- Still technical, but empathetic
- Second-person ("you") to make it personal
- Focuses on what you'll *achieve*

### Examples

| Current | StoryBrand |
|---------|------------|
| "The workshop teaches how to deploy agents securely" | "You'll learn to deploy agents with confidence" |
| "AI agents take actions, not just respond" | "Your agent doesn't just answer questions—it takes action. That's powerful. And risky." |
| "Defense in depth uses three layers" | "We protect your agent with three independent layers—each one works even if the others fail" |

---

## Part 8: Measurement Criteria

After implementation, the workshop should:

1. **Hook in first 30 seconds** - Reader understands their problem is understood
2. **Clear guide positioning** - Workshop feels trustworthy and capable
3. **Simple plan** - Can be summarized in one sentence
4. **Emotional stakes** - Reader feels why this matters
5. **Success vision** - Reader can picture the end state
6. **Consistent narrative** - Story thread runs through all sections

---

## Next Steps

1. **Review this plan** - Confirm direction before implementation
2. **Implement Phase by Phase** - Start with workshop/index.md
3. **Test with fresh eyes** - Have someone new read the opening
4. **Iterate** - Refine based on feedback

---

*This plan applies Donald Miller's StoryBrand framework from "Building a StoryBrand" (2017) to technical workshop content.*

