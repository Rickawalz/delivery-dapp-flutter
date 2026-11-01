# Thesis folder status

The governing text is Chapters 1 and 2, taken from `RLE_Ch1-2_Ch2revised--finished.docx`.

**Title:** Reliable Logistics Exchange (RLE): A Blockchain-Based Delivery Tracking System with Progressive Decentralization

RLE is a proof of concept. It records a simplified delivery lifecycle and tests whether milestone rules and token rewards can support a later transfer of contract control. The reward formula and the handover are evaluated. They are not assumed to work. Full decentralization, as defined in Section 2.8, means no single administrator keeps special authority over the smart contracts. Firebase and Firestore stay under the operator. The Guam account in Section 1.2 is motivation, not a field study.

## Research questions

- **RQ1:** How can a blockchain-based delivery system support transparent and auditable shipment records among independent participants?
- **RQ2:** How can Ethereum smart contracts and a user-facing application be integrated to support a delivery lifecycle from creation through completion?
- **RQ3:** How can RLE begin under centralized administration and use smart contracts, participant roles, token-based participation, and decentralization milestones to support a gradual transfer to full decentralization?
- **RQ4:** What functional, security, performance, privacy, usability, and governance limitations appear when RLE is evaluated?

## Chapter files

Section 1.10 uses five chapters. The drafts that used to be numbered 3–8 are kept as separate files so the technical detail remains, and their headings now follow that outline.

| File | Role in the thesis |
| --- | --- |
| `01_introduction.md` | Chapter 1 |
| `02_literature_review.md` | Chapter 2 |
| `03_methodology.md` | Chapter 3, method |
| `04_design.md` | Chapter 3, design |
| `05_implementation.md` | Chapter 3, implementation |
| `06_evaluation.md` | Chapter 4, results |
| `07_discussion.md` | Chapter 4, discussion |
| `08_conclusion.md` | Chapter 5 |

## What those drafts may still say

The measurement sections still contain gas tables, test counts, and the reward simulation. Read them with Chapters 1 and 2:

- A 2 percent fee field is accounting. It is not a collected payment and it is not a research question.
- `advancePhase` can change a phase label after the owner calls it and the milestones pass. It does not transfer `onlyOwner` authority or create a vote.
- Hashed checkpoints show that a submitted value was recorded. They do not show that a physical shipment was there.
- Simulation results in `blockchain/results/thesis_evaluation_results.json` are gaming reduction 0.0, Gini improvement about 1.38 percent, friend-circle prevention about 1.8 percent, and distance-farming efficiency about 1.45.

## Still outside this folder

The abstract, defense slides, and a single compiled manuscript are not in this folder. Reference [4] in Chapter 2 was an inline revision note in the Word file; the markdown entry uses the DOI from that note.
