# CDR Fee Schedule Prompt Optimization

Optimized prompts for Snowflake Cortex **AI_EXTRACT** to improve fee schedule extraction accuracy from merchant contracts as part of the [Contract Data Repository (CDR)](https://www.notion.so/affirm/Contract-Data-Repository-Hub-7802c1eeb33c41a58cb402831ba73bd8) initiative.

## Background

The CDR is a centralized, AI-powered repository that extracts and structures key terms from Affirm's ~36K+ merchant contracts, making contract data queryable in Snowflake for cross-functional teams.

We use **AI_EXTRACT** (Snowflake Cortex) as the OCR tool for extracting data from contracts. Fee schedules present a unique challenge because they appear as **tables** in contracts rather than plain text, causing AI_EXTRACT to return average confidence scores of **35-50%** -- well below the **85% compliance threshold** required for automated processing.

Snowflake recommended refining prompts as one approach to improving extraction quality.

## Problem Statement

| Issue | Detail |
|-------|--------|
| **Low confidence scores** | Fee schedule extraction averages 35-50% confidence |
| **Compliance requirement** | Any term below 85% confidence requires manual review |
| **Root cause** | Fee schedules are tables (structured data), not plain text |
| **Impact** | Nearly all contracts require manual review for fee schedule data |
| **Prior testing** | Extracting only MDR from the fee schedule did not improve accuracy |

## Optimization Strategies

The file `fee_schedule_prompts_optimized.sql` contains four complementary strategies:

### Strategy A: Full Table Extraction (Structured JSON Schema)

Extracts the entire fee schedule using a JSON schema with `column_ordering`. Includes four variants:
- **A.1** - Standard fee schedule (single MDR column)
- **A.2** - Split MDR (Card/VCN vs Direct/API)
- **A.3** - With cart range and term length columns
- **A.4** - Volume-tiered fee schedules

### Strategy B: Decomposed Single-Field Extractions

Extracts each fee schedule field independently with one question per call. Fields include:
- Number of programs, Affirm products, MDR values, transaction fees
- Customer APR, cart ranges, term lengths
- Card MDR and Direct MDR (separate)

**Trade-off:** More API calls per contract, but likely higher per-field confidence.

### Strategy C: Program-Level Extraction

Extracts data one program at a time (Program A, then Program B, etc.) to reduce ambiguity when tables have multiple rows.

### Strategy D: Hybrid Detection + Targeted Extraction

First detects table structure (location, row count, column layout), then follows up with targeted field extractions using the structural context.

### Reference: Non-Pricing Terms

Optimized prompts for non-pricing contract terms (autorenewal, effective date, right to amend, etc.) are included for reference.

## Key Optimization Principles Applied

Based on [Snowflake's AI_EXTRACT documentation](https://docs.snowflake.com/en/sql-reference/functions/ai_extract) and [table extraction best practices](https://docs.snowflake.com/en/user-guide/snowflake-cortex/document-ai/table-extraction-best-practices):

1. **Use structured JSON schemas** with explicit `column_ordering` matching document layout
2. **Natural-language column names** (e.g., "Affirm Product" not "affirm_product")
3. **Descriptive locator fields** to guide the model to the correct table in the document
4. **One value per question** for decomposed extractions
5. **Specific, unambiguous language** with domain-relevant search cues
6. **Known-answer framing** -- tell the model what format to expect

## Recommended Testing Plan

1. Select ~30 contracts with known fee schedule values (same test set used for prior benchmarking)
2. Run each strategy against the test set
3. Compare confidence scores and extraction accuracy vs. current prompts
4. Identify which strategy (or combination) yields the highest confidence for each field
5. Consider a routing approach: use Strategy D.1 to detect table structure, then apply the appropriate Strategy A variant

## File Structure

```
fee_schedule_prompts_optimized.sql   # All optimized prompts with SQL examples
README.md                            # This file
```
