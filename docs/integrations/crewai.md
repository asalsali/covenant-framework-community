# CrewAI Integration

Add Covenant governance to your existing CrewAI project with two lines of code.

## Install

```bash
pip install crewai-governance
```

## Usage

```python
from crewai.project import CrewBase, before_kickoff, after_kickoff
from crewai_governance import governance_before_kickoff, governance_after_kickoff

@CrewBase
class ResearchCrew:
    @before_kickoff
    def before(self, inputs):
        return governance_before_kickoff(
            crew_name="research_crew",
            mandate="research AI governance papers"
        )(inputs)

    @after_kickoff
    def after(self, result):
        return governance_after_kickoff("research_crew")(result)
```

Two decorators. That is it.

## What you get

| Feature | What it does |
|---|---|
| **Exit reports** | Auto-writes structured JSON after every crew run |
| **Overlap detection** | Scans active crews for mandate overlap before kickoff |
| **Knowledge inheritance** | Injects prior exit report summaries into crew context |
| **Decision tracing** | Structured decision graph across runs |

## Decision tracing

```python
from crewai_governance import Decision, governance_after_kickoff

@after_kickoff
def after(self, result):
    return governance_after_kickoff("my_crew", decisions=[
        Decision(
            summary="Chose RAG over fine-tuning",
            reasoning="Lower cost, faster iteration",
            confidence="high",
            tags=["architecture"],
        ),
    ])(result)
```

Source: github.com/asalsali/crewai-governance
