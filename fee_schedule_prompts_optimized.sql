-- =============================================================================
-- CDR Fee Schedule Prompt Optimization for Snowflake Cortex AI_EXTRACT
-- =============================================================================
--
-- Initiative:  Contract Data Repository (CDR)
--              https://www.notion.so/affirm/Contract-Data-Repository-Hub-7802c1eeb33c41a58cb402831ba73bd8
--
-- Problem:     Fee schedules appear as tables in merchant contracts rather than
--              plain text. AI_EXTRACT returns average confidence scores of
--              35-50%, well below the 85% compliance threshold required for
--              automated processing. Nearly all contracts require manual review.
--
-- Approach:    Refine prompts following Snowflake AI_EXTRACT best practices for
--              table extraction. Key strategies:
--                1. Use structured JSON schemas with explicit column_ordering
--                2. Use natural-language column names matching the document
--                3. Add description/locator fields to guide the model to the
--                   correct table
--                4. Ask for one value per question where possible
--                5. Decompose the fee schedule into targeted single-field
--                   extractions as a fallback
--
-- References:
--   - Snowflake AI_EXTRACT docs:
--     https://docs.snowflake.com/en/sql-reference/functions/ai_extract
--   - Snowflake table extraction best practices:
--     https://docs.snowflake.com/en/user-guide/snowflake-cortex/document-ai/table-extraction-best-practices
-- =============================================================================


-- =============================================================================
-- STRATEGY A: Full Table Extraction (Structured JSON Schema)
-- =============================================================================
-- This approach extracts the entire fee schedule table at once using a JSON
-- schema with column_ordering. The schema mirrors the columns as they appear
-- in Affirm's standard fee schedule tables (left to right).
--
-- Best practices applied:
--   - column_ordering matches document column order
--   - Natural language column names (e.g., "Affirm Product" not "affirm_product")
--   - description field acts as a locator to find the correct table
--   - Handles multi-program fee schedules (Program A, Program B, etc.)
-- =============================================================================

-- Strategy A.1: Standard Fee Schedule (API + VCN split MDR)
SELECT
    ironclad_id,
    contract_name,
    AI_EXTRACT(
        file_url,
        {
            'fee_schedule': {
                'type': 'table',
                'description': 'The Fee Schedule table, also labeled as Schedule 1 or Order Form, containing the merchant pricing terms. This table lists Affirm products, customer APR terms, MDR rates, and transaction fees. Look for column headers such as Affirm Product, Customer APR, MDR, and Transaction Fee.',
                'column_ordering': [
                    'Affirm Product',
                    'Customer APR',
                    'MDR',
                    'Transaction Fee'
                ],
                'columns': {
                    'Affirm Product': {
                        'type': 'string',
                        'description': 'The Affirm financing product name, such as Installments, Pay in 4, Affirm Card, or Adaptive Checkout. May also appear as the program name like Program A or Program B.'
                    },
                    'Customer APR': {
                        'type': 'string',
                        'description': 'The Annual Percentage Rate offered to customers. May be a specific percentage like 0% or 10-36%, or a description such as Qualified Customers receive 1 term length at 0% APR.'
                    },
                    'MDR': {
                        'type': 'string',
                        'description': 'The Merchant Discount Rate as a percentage of the Successful Transaction amount. For example 2.89% or 4.59%.'
                    },
                    'Transaction Fee': {
                        'type': 'string',
                        'description': 'The fixed per-transaction fee charged to the merchant. For example $0.30.'
                    }
                }
            }
        }
    ) AS fee_schedule_extracted
FROM cdr_contracts;


-- Strategy A.2: Fee Schedule with Card MDR vs Direct MDR split
-- Some contracts split MDR into separate Card (VCN) and Direct (API) rates.
SELECT
    ironclad_id,
    contract_name,
    AI_EXTRACT(
        file_url,
        {
            'fee_schedule': {
                'type': 'table',
                'description': 'The Fee Schedule table, also labeled as Schedule 1 or Order Form. This table contains the merchant pricing terms with separate MDR columns for Card and Direct integrations. Look for column headers including Affirm Product, Customer APR, Card MDR or VCN MDR, Direct MDR or API MDR, and Transaction Fee.',
                'column_ordering': [
                    'Affirm Product',
                    'Customer APR',
                    'Card MDR',
                    'Direct MDR',
                    'Transaction Fee'
                ],
                'columns': {
                    'Affirm Product': {
                        'type': 'string',
                        'description': 'The Affirm financing product name such as Installments, Pay in 4, Affirm Card, or Adaptive Checkout.'
                    },
                    'Customer APR': {
                        'type': 'string',
                        'description': 'The Annual Percentage Rate offered to consumers. May be a specific percentage or a description of rate terms.'
                    },
                    'Card MDR': {
                        'type': 'string',
                        'description': 'The Merchant Discount Rate for Card or VCN transactions, as a percentage. Sometimes labeled VCN MDR.'
                    },
                    'Direct MDR': {
                        'type': 'string',
                        'description': 'The Merchant Discount Rate for Direct API transactions, as a percentage. Sometimes labeled API MDR.'
                    },
                    'Transaction Fee': {
                        'type': 'string',
                        'description': 'The fixed dollar fee per successful transaction, such as $0.30.'
                    }
                }
            }
        }
    ) AS fee_schedule_extracted
FROM cdr_contracts;


-- Strategy A.3: Fee Schedule with Cart Range and Term Length columns
-- Some contracts include cart size thresholds and specific term lengths.
SELECT
    ironclad_id,
    contract_name,
    AI_EXTRACT(
        file_url,
        {
            'fee_schedule': {
                'type': 'table',
                'description': 'The Fee Schedule table, also labeled as Schedule 1 or Order Form, that defines merchant pricing by cart range and financing term. Look for column headers such as Affirm Product, Cart Range or Cart Size, Term Length, Customer APR, MDR, and Transaction Fee.',
                'column_ordering': [
                    'Affirm Product',
                    'Cart Range',
                    'Term Length',
                    'Customer APR',
                    'MDR',
                    'Transaction Fee'
                ],
                'columns': {
                    'Affirm Product': {
                        'type': 'string',
                        'description': 'The Affirm financing product name such as Installments, Pay in 4, or Affirm Card.'
                    },
                    'Cart Range': {
                        'type': 'string',
                        'description': 'The cart size or transaction amount range, such as $1 - $250 or $250.01 - $17,500. Also called Cart Size.'
                    },
                    'Term Length': {
                        'type': 'string',
                        'description': 'The loan repayment term in months, such as 3, 6, 12, 18, 24, or 36 months. May also say Pay in 4 for bi-weekly payments.'
                    },
                    'Customer APR': {
                        'type': 'string',
                        'description': 'The Annual Percentage Rate for the consumer, such as 0% or 10-36%.'
                    },
                    'MDR': {
                        'type': 'string',
                        'description': 'The Merchant Discount Rate as a percentage, such as 2.89%.'
                    },
                    'Transaction Fee': {
                        'type': 'string',
                        'description': 'The fixed dollar fee per transaction, such as $0.30.'
                    }
                }
            }
        }
    ) AS fee_schedule_extracted
FROM cdr_contracts;


-- Strategy A.4: Volume-Tiered Fee Schedule
-- Some contracts have volume-based pricing tiers with MDR discounts.
SELECT
    ironclad_id,
    contract_name,
    AI_EXTRACT(
        file_url,
        {
            'fee_schedule': {
                'type': 'table',
                'description': 'The Fee Schedule table containing volume-tiered merchant pricing. This table includes tiers based on Affirm Successful Transaction Volume, with corresponding MDR Discounts. Look for column headers such as Tier, Affirm Successful Transaction Volume, and MDR Discount.',
                'column_ordering': [
                    'Tier',
                    'Affirm Successful Transaction Volume',
                    'MDR Discount'
                ],
                'columns': {
                    'Tier': {
                        'type': 'string',
                        'description': 'The volume tier number or label, such as Tier 1, Tier 2, or Tier 3.'
                    },
                    'Affirm Successful Transaction Volume': {
                        'type': 'string',
                        'description': 'The transaction volume range qualifying for this tier, such as $0 - $100,000,000 or Greater than $200,000,001.'
                    },
                    'MDR Discount': {
                        'type': 'string',
                        'description': 'The percentage discount applied to the base MDR when this tier is reached, such as 0% or 0.10%.'
                    }
                }
            }
        }
    ) AS fee_schedule_extracted
FROM cdr_contracts;


-- =============================================================================
-- STRATEGY B: Decomposed Single-Field Extractions
-- =============================================================================
-- When full-table extraction yields low confidence, extract each field
-- independently. This approach asks one specific question per call, which
-- Snowflake recommends for higher accuracy.
--
-- Trade-off: Requires multiple AI_EXTRACT calls per contract but may
-- produce significantly higher per-field confidence scores.
-- =============================================================================

-- B.1: Number of unique fee schedules / programs
SELECT
    ironclad_id,
    AI_EXTRACT(
        file_url,
        {
            'number_of_programs': {
                'type': 'integer',
                'description': 'How many distinct financing programs or product bundles are listed in the Fee Schedule table? Count each row or group that represents a different Affirm product or program (e.g., Program A, Program B). Return the count as a number.'
            }
        }
    ):number_of_programs::INTEGER AS num_programs
FROM cdr_contracts;


-- B.2: Affirm Product names
SELECT
    ironclad_id,
    AI_EXTRACT(
        file_url,
        {
            'affirm_products': {
                'type': 'string',
                'description': 'What are the Affirm product names listed in the Fee Schedule table? Look for product names in the column labeled Affirm Product. Common values include Installments, Pay in 4, Adaptive Checkout, and Affirm Card. Return all product names separated by semicolons.'
            }
        }
    ):affirm_products::VARCHAR AS affirm_products
FROM cdr_contracts;


-- B.3: MDR values
SELECT
    ironclad_id,
    AI_EXTRACT(
        file_url,
        {
            'mdr_values': {
                'type': 'string',
                'description': 'What are the Merchant Discount Rate (MDR) percentages listed in the Fee Schedule table? The MDR is the percentage of each Successful Transaction that the merchant pays to Affirm. Look in the column labeled MDR, or in columns labeled Card MDR and Direct MDR. Return all MDR values as percentages separated by semicolons, in the same order they appear in the table.'
            }
        }
    ):mdr_values::VARCHAR AS mdr_values
FROM cdr_contracts;


-- B.4: Transaction Fee
SELECT
    ironclad_id,
    AI_EXTRACT(
        file_url,
        {
            'transaction_fee': {
                'type': 'string',
                'description': 'What is the per-transaction fee listed in the Fee Schedule table? This is a fixed dollar amount charged per Successful Transaction, typically labeled Transaction Fee. Common values are $0.30 or $0.00. Return the dollar amount.'
            }
        }
    ):transaction_fee::VARCHAR AS transaction_fee
FROM cdr_contracts;


-- B.5: Customer APR terms
SELECT
    ironclad_id,
    AI_EXTRACT(
        file_url,
        {
            'customer_apr': {
                'type': 'string',
                'description': 'What are the Customer APR terms listed in the Fee Schedule table? Look in the column labeled Customer APR. The APR may be a specific rate like 0%, a range like 10-36%, or descriptive text like Qualified Customers receive 1 term length at 0% APR. Return all APR values separated by semicolons, in the order they appear.'
            }
        }
    ):customer_apr::VARCHAR AS customer_apr
FROM cdr_contracts;


-- B.6: Cart Range / Cart Size
SELECT
    ironclad_id,
    AI_EXTRACT(
        file_url,
        {
            'cart_range': {
                'type': 'string',
                'description': 'What are the cart size ranges or minimum and maximum transaction amounts listed in the Fee Schedule table? Look for columns labeled Cart Range, Cart Size, Minimum Transaction Amount, or Maximum Transaction Amount. Return all ranges separated by semicolons.'
            }
        }
    ):cart_range::VARCHAR AS cart_range
FROM cdr_contracts;


-- B.7: Term Length
SELECT
    ironclad_id,
    AI_EXTRACT(
        file_url,
        {
            'term_length': {
                'type': 'string',
                'description': 'What term lengths are listed in the Fee Schedule table? Term lengths indicate the repayment period in months, such as 3, 6, 12, 18, 24, or 36 months. Pay in 4 refers to bi-weekly payments over approximately 2 months. Return all term lengths separated by semicolons.'
            }
        }
    ):term_length::VARCHAR AS term_length
FROM cdr_contracts;


-- B.8: Card MDR (VCN) specifically
SELECT
    ironclad_id,
    AI_EXTRACT(
        file_url,
        {
            'card_mdr': {
                'type': 'string',
                'description': 'What is the Card MDR or VCN MDR percentage in the Fee Schedule table? This is the Merchant Discount Rate specifically for virtual card network (VCN) or card-based transactions. It appears in a column labeled Card MDR, VCN MDR, or Pricing (VCN). Return the percentage value. If there is no separate Card MDR column, return N/A.'
            }
        }
    ):card_mdr::VARCHAR AS card_mdr
FROM cdr_contracts;


-- B.9: Direct MDR (API) specifically
SELECT
    ironclad_id,
    AI_EXTRACT(
        file_url,
        {
            'direct_mdr': {
                'type': 'string',
                'description': 'What is the Direct MDR or API MDR percentage in the Fee Schedule table? This is the Merchant Discount Rate specifically for direct API transactions. It appears in a column labeled Direct MDR, API MDR, or Pricing (API). Return the percentage value. If there is no separate Direct MDR column, return N/A.'
            }
        }
    ):direct_mdr::VARCHAR AS direct_mdr
FROM cdr_contracts;


-- =============================================================================
-- STRATEGY C: Program-Level Extraction (One Row per Program)
-- =============================================================================
-- Extracts fee schedule data per financing program. When a fee schedule has
-- multiple programs (e.g., Program A and Program B), this approach isolates
-- each program's data into a separate extraction to reduce ambiguity.
-- =============================================================================

-- C.1: First/Primary program extraction
SELECT
    ironclad_id,
    AI_EXTRACT(
        file_url,
        {
            'program_name': {
                'type': 'string',
                'description': 'What is the name of the first financing program listed in the Fee Schedule table? This is typically the first row or first group in the table. It may be labeled as Program A, Program 1, or by the Affirm product name such as Installments or Pay in 4.'
            },
            'program_product': {
                'type': 'string',
                'description': 'For the first program in the Fee Schedule, what Affirm product is listed? Look in the Affirm Product column for the first row or group.'
            },
            'program_apr': {
                'type': 'string',
                'description': 'For the first program in the Fee Schedule, what is the Customer APR? Return the APR value or description from the first row or group.'
            },
            'program_mdr': {
                'type': 'string',
                'description': 'For the first program in the Fee Schedule, what is the MDR percentage? Return the Merchant Discount Rate from the first row or group.'
            },
            'program_txn_fee': {
                'type': 'string',
                'description': 'For the first program in the Fee Schedule, what is the transaction fee? Return the per-transaction dollar amount from the first row or group.'
            }
        }
    ) AS program_1_data
FROM cdr_contracts;


-- C.2: Second program extraction
SELECT
    ironclad_id,
    AI_EXTRACT(
        file_url,
        {
            'program_name': {
                'type': 'string',
                'description': 'What is the name of the second financing program listed in the Fee Schedule table? This is the second row or second group. It may be labeled Program B, Program 2, or by a different Affirm product name. If there is no second program, return N/A.'
            },
            'program_product': {
                'type': 'string',
                'description': 'For the second program in the Fee Schedule, what Affirm product is listed? If there is no second program, return N/A.'
            },
            'program_apr': {
                'type': 'string',
                'description': 'For the second program in the Fee Schedule, what is the Customer APR? If there is no second program, return N/A.'
            },
            'program_mdr': {
                'type': 'string',
                'description': 'For the second program in the Fee Schedule, what is the MDR percentage? If there is no second program, return N/A.'
            },
            'program_txn_fee': {
                'type': 'string',
                'description': 'For the second program in the Fee Schedule, what is the transaction fee? If there is no second program, return N/A.'
            }
        }
    ) AS program_2_data
FROM cdr_contracts;


-- =============================================================================
-- STRATEGY D: Hybrid - Table Schema + Targeted Follow-Up
-- =============================================================================
-- Combines a lightweight table extraction with targeted follow-up queries
-- for specific high-value fields. Use the table extraction for structural
-- understanding, then validate critical fields with single-value prompts.
-- =============================================================================

-- D.1: Lightweight table structure detection
SELECT
    ironclad_id,
    AI_EXTRACT(
        file_url,
        {
            'has_fee_schedule': {
                'type': 'boolean',
                'description': 'Does this document contain a Fee Schedule table? A Fee Schedule is a table that lists Affirm financing products with their associated MDR rates and transaction fees. It may be labeled Fee Schedule, Schedule 1, or Order Form. Answer true or false.'
            },
            'fee_schedule_location': {
                'type': 'string',
                'description': 'Where in the document is the Fee Schedule table located? Return the section name, exhibit number, or schedule number where the fee table appears. For example: Schedule 1, Exhibit A, Order Form No. 1, or Appendix B.'
            },
            'num_rows': {
                'type': 'integer',
                'description': 'How many data rows are in the Fee Schedule table? Do not count header rows. Count each row that contains an Affirm product with its pricing terms.'
            },
            'has_split_mdr': {
                'type': 'boolean',
                'description': 'Does the Fee Schedule table have separate columns for Card MDR (or VCN MDR) and Direct MDR (or API MDR)? Answer true if there are two distinct MDR columns, false if there is only one MDR column.'
            }
        }
    ) AS fee_schedule_metadata
FROM cdr_contracts;


-- D.2: Targeted MDR extraction with maximum context
SELECT
    ironclad_id,
    AI_EXTRACT(
        file_url,
        {
            'primary_mdr': {
                'type': 'string',
                'description': 'In the Fee Schedule table (also called Schedule 1 or Order Form), what is the MDR percentage for the first program listed? The MDR stands for Merchant Discount Rate and represents the percentage of each Successful Transaction paid by the merchant. Look in the column labeled MDR. Return only the percentage value, such as 2.89%.'
            }
        }
    ):primary_mdr::VARCHAR AS primary_mdr
FROM cdr_contracts;


-- =============================================================================
-- REFERENCE: Non-Pricing Term Prompts (Optimized)
-- =============================================================================
-- These prompts extract non-pricing contract terms. They are included here
-- as reference since the same optimization principles apply.
-- =============================================================================

-- Autorenewal
-- Original:  "Does this agreement automatically renew after the initial term?
--             Please answer yes or no"
-- Optimized:
SELECT
    ironclad_id,
    AI_EXTRACT(
        file_url,
        {
            'autorenewal': {
                'type': 'string',
                'description': 'Does this agreement contain an automatic renewal clause? Look in the Term section for language about the agreement automatically renewing for additional or successive periods after the Initial Term. Answer yes or no.'
            }
        }
    ):autorenewal::VARCHAR AS autorenewal
FROM cdr_contracts;


-- Autorenewal Period
-- Original:  "in the term section, what is the automatic renewal period or
--             renewal term of this agreement as listed in the term section?"
-- Optimized:
SELECT
    ironclad_id,
    AI_EXTRACT(
        file_url,
        {
            'autorenewal_period': {
                'type': 'string',
                'description': 'In the Term section, what is the duration of each automatic renewal period? Look for phrases like automatically renew for additional one-year periods or successive twelve-month periods. Return the renewal period length, such as one year or 12 months. If no renewal period is specified, return N/A.'
            }
        }
    ):autorenewal_period::VARCHAR AS autorenewal_period
FROM cdr_contracts;


-- Effective Date
-- Original:  "What date did the merchant sign the agreement? What date was the
--             agreement first signed?"
-- Optimized:
SELECT
    ironclad_id,
    AI_EXTRACT(
        file_url,
        {
            'effective_date': {
                'type': 'string',
                'description': 'What is the effective date of this agreement? Look for the date the agreement was signed or became effective. This is typically found on the signature page or in the opening paragraph. Return the date in YYYY-MM-DD format.'
            }
        }
    ):effective_date::VARCHAR AS effective_date
FROM cdr_contracts;


-- Right to Amend
-- Original:  (not provided in search results)
-- Optimized:
SELECT
    ironclad_id,
    AI_EXTRACT(
        file_url,
        {
            'right_to_amend': {
                'type': 'string',
                'description': 'Does this agreement contain a clause giving Affirm the right to amend the agreement terms? Look for language about Affirm being able to modify, amend, or update the terms upon written notice. Answer yes or no.'
            }
        }
    ):right_to_amend::VARCHAR AS right_to_amend
FROM cdr_contracts;


-- Right to Revise Fees
-- Optimized:
SELECT
    ironclad_id,
    AI_EXTRACT(
        file_url,
        {
            'right_to_revise_fees': {
                'type': 'string',
                'description': 'Does this agreement contain a clause allowing Affirm to revise the merchant fees? Look for language stating Affirm may reduce or revise fees upon written notice to Merchant. This is often called Right to Revise Fees or Notwithstanding anything to the contrary. Answer yes or no.'
            }
        }
    ):right_to_revise_fees::VARCHAR AS right_to_revise_fees
FROM cdr_contracts;


-- Notice Period
-- Optimized:
SELECT
    ironclad_id,
    AI_EXTRACT(
        file_url,
        {
            'notice_period': {
                'type': 'string',
                'description': 'What is the required notice period for termination or non-renewal of this agreement? Look for language about providing written notice a certain number of days before the end of the term or renewal period. Return the number of days, such as 30 days or 60 days. If no notice period is specified, return N/A.'
            }
        }
    ):notice_period::VARCHAR AS notice_period
FROM cdr_contracts;


-- Direct Debit
-- Optimized:
SELECT
    ironclad_id,
    AI_EXTRACT(
        file_url,
        {
            'direct_debit': {
                'type': 'string',
                'description': 'Does this agreement contain a Direct Debit clause allowing Affirm to directly debit the merchant bank account for fees owed? Look for language about Affirm being authorized to debit or offset amounts from merchant payouts or bank accounts. Answer yes or no.'
            }
        }
    ):direct_debit::VARCHAR AS direct_debit
FROM cdr_contracts;


-- Product Innovation / Flexible Fee Schedule
-- Optimized:
SELECT
    ironclad_id,
    AI_EXTRACT(
        file_url,
        {
            'product_innovation': {
                'type': 'string',
                'description': 'Does this agreement contain a Product Innovation clause or Flexible Fee Schedule clause? This clause allows Affirm to adjust financing programs, add new products, or modify APR and term configurations without requiring a contract amendment, as long as the MDR does not increase. Answer yes or no.'
            }
        }
    ):product_innovation::VARCHAR AS product_innovation
FROM cdr_contracts;


-- Exclusivity
-- Optimized:
SELECT
    ironclad_id,
    AI_EXTRACT(
        file_url,
        {
            'exclusivity': {
                'type': 'string',
                'description': 'Does this agreement contain an exclusivity clause? Look for language requiring the merchant to use Affirm exclusively as their buy-now-pay-later or installment payment provider, or restricting the merchant from offering competing BNPL services. Answer yes or no.'
            }
        }
    ):exclusivity::VARCHAR AS exclusivity
FROM cdr_contracts;


-- Merchant Name
-- Optimized:
SELECT
    ironclad_id,
    AI_EXTRACT(
        file_url,
        {
            'merchant_name': {
                'type': 'string',
                'description': 'What is the legal entity name of the merchant in this agreement? Look on the signature page or in the opening paragraph for the company name that is entering into the agreement with Affirm. Do not return Affirm Inc. Return only the merchant or counterparty legal entity name.'
            }
        }
    ):merchant_name::VARCHAR AS merchant_name
FROM cdr_contracts;


-- Country / Territory
-- Optimized:
SELECT
    ironclad_id,
    AI_EXTRACT(
        file_url,
        {
            'territory': {
                'type': 'string',
                'description': 'What territory or country does this agreement cover? Look for a Territory definition, which typically specifies the geographic scope such as the United States, Canada, or specific states and jurisdictions. Return the territory as stated in the agreement.'
            }
        }
    ):territory::VARCHAR AS territory
FROM cdr_contracts;
