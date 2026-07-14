---
kind: apple-orchestrator-workflow-agent
id: contract-review
name: Contract Review
default_model: qwen3.6:35b-mlx
---

# Contract Review

Review a selected contract against the client or matter context, identify material commercial and legal risks, request attorney decisions where needed, and generate a traceable review memorandum.
- Workflow Agent: Contract Review
  <!-- ao-node kind=workflow id=Y29udHJhY3QtcmV2aWV3 name=Q29udHJhY3QgUmV2aWV3 detail=UmV2aWV3IGEgc2VsZWN0ZWQgY29udHJhY3QgYWdhaW5zdCB0aGUgY2xpZW50IG9yIG1hdHRlciBjb250ZXh0LCBpZGVudGlmeSBtYXRlcmlhbCBjb21tZXJjaWFsIGFuZCBsZWdhbCByaXNrcywgcmVxdWVzdCBhdHRvcm5leSBkZWNpc2lvbnMgd2hlcmUgbmVlZGVkLCBhbmQgZ2VuZXJhdGUgYSB0cmFjZWFibGUgcmV2aWV3IG1lbW9yYW5kdW0u model=cXdlbjMuNjozNWItbWx4 required=1 events=d29ya2Zsb3cuc3RhcnRlZB93b3JrZmxvdy5jb21wbGV0ZWQfd29ya2Zsb3cuZmFpbGVk -->
  > Review a selected contract against the client or matter context, identify material commercial and legal risks, request attorney decisions where needed, and generate a traceable review memorandum.
  - Phase: Review
    <!-- ao-node kind=phase id=UmV2aWV3 name=UmV2aWV3 detail=UmV2aWV3IHRoZSBjb250cmFjdCBhbmQgZXN0YWJsaXNoIHRoZSBzb3VyY2UgcGFja2V0Lg__ model= required=1 events=c3RhZ2Uuc3RhcnRlZB9zdGFnZS5jb21wbGV0ZWQfc3RhZ2UuZmFpbGVk -->
    > Review the contract and establish the source packet.
    - Work Unit: Review Contract
      <!-- ao-node kind=work_unit id=UmV2aWV3IENvbnRyYWN0 name=UmV2aWV3IENvbnRyYWN0 detail=QnVpbGQgYSBkZWNpc2lvbi1yZWFkeSBjb250cmFjdCByZXZpZXcgcGFja2V0IGZyb20gc2VsZWN0ZWQgZG9jdW1lbnRzLCBzcGVjaWFsaXN0IGZpbmRpbmdzLCBhbmQgcmVjb3JkZWQgYXR0b3JuZXkgZGlyZWN0aW9ucy4gQ29tcGxldGlvbiBib3VuZGFyeTogdGhpcyB1bml0IGlzIGNvbXBsZXRlIG9ubHkgYWZ0ZXIgaXRzIHJlcXVpcmVkIHRlYW0gcGFja2V0IGFuZCBuYW1lZCBvdXRwdXRzIGFyZSBwZXJzaXN0ZWQsIG9ic2VydmFibGUsIGFuZCB1c2FibGUgYnkgdGhlIG5leHQgd29ya2Zsb3cgc3RlcC4_ model=cXdlbjMuNjozNWItbWx4 required=1 events=d29ya191bml0LnN0YXJ0ZWRfd29ya191bml0LmNvbXBsZXRlZF93b3JrX3VuaXQuZmFpbGVk -->
      > Build a decision-ready contract review packet from selected documents, specialist findings, and recorded attorney directions. Completion boundary: this unit is complete only after its required team packet and named outputs are persisted, observable, and usable by the next workflow step.
      - Work Team: Contract Review Team
        <!-- ao-node kind=work_team id=Q29udHJhY3QgUmV2aWV3IFRlYW0_ name=Q29udHJhY3QgUmV2aWV3IFRlYW0_ detail=QW5hbHl6ZSBjb21tZXJjaWFsIHRlcm1zIGFuZCByZXR1cm4gYW4gZXZpZGVuY2UtYmFja2VkIHJldmlldyBwYWNrZXQuIFRlYW0gYm91bmRhcnk6IGVhY2ggcm9sZSBwZXJmb3JtcyBvbmx5IGl0cyBhc3NpZ25lZCByZXNwb25zaWJpbGl0eTsgdGhlIHRlYW0gcmV0dXJucyBvbmUgdHJhY2VhYmxlIHBhY2tldCB0aGF0IHByZXNlcnZlcyByb2xlIG91dHB1dHMsIHdhcm5pbmdzLCBkaXNhZ3JlZW1lbnRzLCBhbmQgYW55IGVzY2FsYXRpb24u model= required=1 events=dGVhbS5zdGFydGVkH3RlYW0uY29tcGxldGVkH3RlYW0uZmFpbGVk -->
        > Analyze commercial terms and return an evidence-backed review packet. Team boundary: each role performs only its assigned responsibility; the team returns one traceable packet that preserves role outputs, warnings, disagreements, and any escalation.
        - Role: Contract Reviewer
          <!-- ao-node kind=role id=Y29udHJhY3QtcmV2aWV3ZXI_ name=Q29udHJhY3QgUmV2aWV3ZXI_ detail=UmV2aWV3IHRoZSBjb250cmFjdCBvbmx5IGZyb20gc3VwcGxpZWQgc291cmNlIHRleHQgYW5kIGNvbnRleHQ7IGlkZW50aWZ5IG1hdGVyaWFsIGZpbmRpbmdzLCBjaXRhdGlvbnMsIGNvbmZpZGVuY2UsIGFuZCByZXF1aXJlZCBhdHRvcm5leSBkZWNpc2lvbnMuIFJvbGUgYm91bmRhcnk6IHdpdGhpbiBDb250cmFjdCBSZXZpZXcgVGVhbSwgdGhpcyByb2xlIG93bnMgb25seSBpdHMgY29udHJpYnV0aW9uIHRvIFJldmlldyBDb250cmFjdCwgdXNlcyB0aGUgbGlzdGVkIGNhcGFiaWxpdGllcywgcmV0dXJucyBhbiBldmlkZW5jZS1iYWNrZWQgcm9sZSBwYWNrZXQsIGFuZCBlc2NhbGF0ZXMgdW5yZXNvbHZlZCBsZWdhbCBqdWRnbWVudCByYXRoZXIgdGhhbiBjb250aW51aW5nIGludG8gYW5vdGhlciByZXNwb25zaWJpbGl0eS4_ model=bGVnYWwtY29udHJhY3Qtc3BlY2lhbGlzdA__ required=1 events=cm9sZS5zdGFydGVkH3JvbGUuY29tcGxldGVkH3JvbGUuZmFpbGVk -->
          > Review the contract only from supplied source text and context; identify material findings, citations, confidence, and required attorney decisions. Role boundary: within Contract Review Team, this role owns only its contribution to Review Contract, uses the listed capabilities, returns an evidence-backed role packet, and escalates unresolved legal judgment rather than continuing into another responsibility.
          - Skill: legal-specialist-review
            <!-- ao-node kind=skill id=bGVnYWwtc3BlY2lhbGlzdC1yZXZpZXc_ name=bGVnYWwtc3BlY2lhbGlzdC1yZXZpZXc_ detail=UmV2aWV3IHNlbGVjdGVkIGNvbnRyYWN0IHRlcm1zIGFuZCBwcm9kdWNlIGEgdHJhY2VhYmxlIG1lbW9yYW5kdW0gd2l0aCBjaXRhdGlvbnMsIHJpc2tzLCBhbmQgbmV4dCBhY3Rpb25zLg__ model= required=1 events= -->
            > Review selected contract terms and produce a traceable memorandum with citations, risks, and next actions.
          - Tool: workflow_extract_text
            <!-- ao-node kind=tool id=d29ya2Zsb3dfZXh0cmFjdF90ZXh0 name=d29ya2Zsb3dfZXh0cmFjdF90ZXh0 detail=UmV2aWV3IHNlbGVjdGVkIGNvbnRyYWN0IHRlcm1zIGFuZCBwcm9kdWNlIGEgdHJhY2VhYmxlIG1lbW9yYW5kdW0gd2l0aCBjaXRhdGlvbnMsIHJpc2tzLCBhbmQgbmV4dCBhY3Rpb25zLg__ model= required=1 events=dG9vbC5zdGFydGVkH3Rvb2wuY29tcGxldGVkH3Rvb2wuZmFpbGVk -->
            > Review selected contract terms and produce a traceable memorandum with citations, risks, and next actions.
      - Output: outputs.contract-review-memorandum
        <!-- ao-node kind=output id=b3V0cHV0cy5jb250cmFjdC1yZXZpZXctbWVtb3JhbmR1bQ__ name=b3V0cHV0cy5jb250cmFjdC1yZXZpZXctbWVtb3JhbmR1bQ__ detail=UHJlc2VydmUgYSBmaW5hbCBNYXJrZG93biBtZW1vcmFuZHVtIHdpdGggY2l0YXRpb25zLCBkZWNpc2lvbnMsIGFuZCByZXF1aXJlZCBuZXh0IHN0ZXBzLg__ model= required=1 events=b3V0cHV0LndyaXR0ZW5fb3V0cHV0LnZhbGlkYXRlZF9vdXRwdXQuZmFpbGVk -->
        > Preserve a final Markdown memorandum with citations, decisions, and required next steps.

## Workflow Product

### Overview

Contract Review turns one or more selected agreements into a decision-ready legal review. It identifies the contract facts, evaluates material clauses through bounded specialist work, requests human judgment for decisions that require it, and releases a cited memorandum after review is complete.

### Benefits

- Gives legal teams a repeatable, traceable contract-review path.
- Preserves document citations, findings, and reviewer decisions in the final memorandum.
- Keeps specialist work bounded so a later workflow can add a privacy, employment, or real-estate review team without changing the core interface.

### Test Cases

#### Vendor Agreement Review
- **Goal:** Review a vendor agreement for commercial, privacy, and liability risks.
- **Fixture:** `test-fixtures/legal/document-onboarding/acme-renewal`
- **Expected:** A cited contract-review memorandum with an attorney decision packet.
- **Review:** Liability, data scope, dispute terms, and signature authority are reviewable.
- **Runnable:** no

### User Guide

Select Contract Review from Documents, choose local files or an approved client matter, inspect the review packet, and resolve any attorney decisions before the memorandum is released.

### Admin

Maintain phases, teams, roles, skills, tools, events, output contracts, and invocation contracts in this workflow-agent Markdown source through the Workflow Agent Builder.

- Workflow Agent: Contract Review
  <!-- ao-node kind=workflow id=Y29udHJhY3QtcmV2aWV3 name=Q29udHJhY3QgUmV2aWV3 detail=UmV2aWV3IGEgc2VsZWN0ZWQgY29udHJhY3QgYWdhaW5zdCB0aGUgY2xpZW50IG9yIG1hdHRlciBjb250ZXh0LCBpZGVudGlmeSBtYXRlcmlhbCBjb21tZXJjaWFsIGFuZCBsZWdhbCByaXNrcywgcmVxdWVzdCBhdHRvcm5leSBkZWNpc2lvbnMgd2hlcmUgbmVlZGVkLCBhbmQgZ2VuZXJhdGUgYSB0cmFjZWFibGUgcmV2aWV3IG1lbW9yYW5kdW0u model=cXdlbjMuNjozNWItbWx4 required=1 events=d29ya2Zsb3cuc3RhcnRlZB93b3JrZmxvdy5jb21wbGV0ZWQfd29ya2Zsb3cuZmFpbGVk -->
  > Review a selected contract against the client or matter context, identify material commercial and legal risks, request attorney decisions where needed, and generate a traceable review memorandum.
  - Phase: Review
    <!-- ao-node kind=phase id=UmV2aWV3 name=UmV2aWV3 detail=UmV2aWV3IHRoZSBjb250cmFjdCBhbmQgZXN0YWJsaXNoIHRoZSBzb3VyY2UgcGFja2V0Lg__ model= required=1 events=c3RhZ2Uuc3RhcnRlZB9zdGFnZS5jb21wbGV0ZWQfc3RhZ2UuZmFpbGVk -->
    > Establish the source packet, review material terms, and preserve evidence-backed findings for downstream decisions.
    - Work Unit: Review Contract
      <!-- ao-node kind=work_unit id=UmV2aWV3IENvbnRyYWN0 name=UmV2aWV3IENvbnRyYWN0 detail=QnVpbGQgYSBkZWNpc2lvbi1yZWFkeSBjb250cmFjdCByZXZpZXcgcGFja2V0IGZyb20gc2VsZWN0ZWQgZG9jdW1lbnRzLCBzcGVjaWFsaXN0IGZpbmRpbmdzLCBhbmQgcmVjb3JkZWQgYXR0b3JuZXkgZGlyZWN0aW9ucy4_ model=cXdlbjMuNjozNWItbWx4 required=1 events=d29ya191bml0LnN0YXJ0ZWRfd29ya191bml0LmNvbXBsZXRlZF93b3JrX3VuaXQuZmFpbGVk -->
      > Build a decision-ready contract review packet from selected documents, specialist findings, and recorded attorney directions.
      - Work Team: Contract Review Team
        <!-- ao-node kind=work_team id=Q29udHJhY3QgUmV2aWV3IFRlYW0_ name=Q29udHJhY3QgUmV2aWV3IFRlYW0_ detail=QW5hbHl6ZSBjb21tZXJjaWFsIHRlcm1zIGFuZCByZXR1cm4gYW4gZXZpZGVuY2UtYmFja2VkIHJldmlldyBwYWNrZXQu model= required=1 events=dGVhbS5zdGFydGVkH3RlYW0uY29tcGxldGVkH3RlYW0uZmFpbGVk -->
        > Analyze commercial terms and return an evidence-backed review packet.
        - Role: Contract Reviewer
          <!-- ao-node kind=role id=Y29udHJhY3QtcmV2aWV3ZXI_ name=Q29udHJhY3QgUmV2aWV3ZXI_ detail=UmV2aWV3IHRoZSBjb250cmFjdCBvbmx5IGZyb20gc3VwcGxpZWQgc291cmNlIHRleHQgYW5kIGNvbnRleHQ7IGlkZW50aWZ5IG1hdGVyaWFsIGZpbmRpbmdzLCBjaXRhdGlvbnMsIGNvbmZpZGVuY2UsIGFuZCByZXF1aXJlZCBhdHRvcm5leSBkZWNpc2lvbnMu model=bGVnYWwtY29udHJhY3Qtc3BlY2lhbGlzdA__ required=1 events=cm9sZS5zdGFydGVkH3JvbGUuY29tcGxldGVkH3JvbGUuZmFpbGVk -->
          > Review only supplied contract text and context; identify material findings, citations, confidence, and decisions requiring attorney judgment.
          - Skill: legal-specialist-review
            <!-- ao-node kind=skill id=bGVnYWwtc3BlY2lhbGlzdC1yZXZpZXc_ name=bGVnYWwtc3BlY2lhbGlzdC1yZXZpZXc_ detail=UmV2aWV3IHNlbGVjdGVkIGNvbnRyYWN0IHRlcm1zIGFuZCBwcm9kdWNlIGEgdHJhY2VhYmxlIG1lbW9yYW5kdW0gd2l0aCBjaXRhdGlvbnMsIHJpc2tzLCBhbmQgbmV4dCBhY3Rpb25zLg__ model= required=1 events= -->
            > Apply the reusable legal specialist review standard to the contract-review role.
          - Tool: workflow_extract_text
            <!-- ao-node kind=tool id=d29ya2Zsb3dfZXh0cmFjdF90ZXh0 name=d29ya2Zsb3dfZXh0cmFjdF90ZXh0 detail=UmV2aWV3IHNlbGVjdGVkIGNvbnRyYWN0IHRlcm1zIGFuZCBwcm9kdWNlIGEgdHJhY2VhYmxlIG1lbW9yYW5kdW0gd2l0aCBjaXRhdGlvbnMsIHJpc2tzLCBhbmQgbmV4dCBhY3Rpb25zLg__ model= required=1 events=dG9vbC5zdGFydGVkH3Rvb2wuY29tcGxldGVkH3Rvb2wuZmFpbGVk -->
            > Extract readable contract text while preserving source references and extraction limits.
      - Output: outputs.contract-review-memorandum
        <!-- ao-node kind=output id=b3V0cHV0cy5jb250cmFjdC1yZXZpZXctbWVtb3JhbmR1bQ__ name=b3V0cHV0cy5jb250cmFjdC1yZXZpZXctbWVtb3JhbmR1bQ__ detail=UHJlc2VydmUgYSBmaW5hbCBNYXJrZG93biBtZW1vcmFuZHVtIHdpdGggY2l0YXRpb25zLCBkZWNpc2lvbnMsIGFuZCByZXF1aXJlZCBuZXh0IHN0ZXBzLg__ model= required=1 events=b3V0cHV0LndyaXR0ZW5fb3V0cHV0LnZhbGlkYXRlZF9vdXRwdXQuZmFpbGVk -->
        > Preserve a final Markdown memorandum with citations, decisions, and required next steps.

## Invocation Contracts

<!-- ao-invocation-contract id="contract-reviewer" -->
# Contract Reviewer Assignment

Identify material commercial and legal terms, state the evidence, confidence, practical consequence, and recommended next action. Flag decisions requiring attorney judgment rather than presenting them as settled advice.
<!-- /ao-invocation-contract -->

<!-- ao-invocation-contract id="legal-role-base" -->
# Shared Role Contract

Use direct document evidence and stable citations. Separate facts, inferences, recommendations, and open questions. Return only the packet required by the assigned work unit.
<!-- /ao-invocation-contract -->

<!-- ao-invocation-contract id="workflow-operating-contract" -->
# Contract Review Operating Contract

Perform only the assigned bounded responsibility. Treat the supplied source packet and recorded reviewer decisions as authoritative. Escalate missing evidence or legal judgment to a human instead of inventing a conclusion.
<!-- /ao-invocation-contract -->

<!-- /ao-invocation-contracts -->
