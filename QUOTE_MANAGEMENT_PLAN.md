# Plan: Custom Quote Management (Quote Manager on the Home page)

## Context
`PROJECT_REQUIREMENTS.md` asks for a quote management screen for a customer that has no Salesforce CPQ license. It needs custom Quote and Quote Line objects, plus an LWC with:
- a header that shows aggregates: total list price, total negotiated price, total discount and discount %
- a table of quote lines with full create, read, update and delete (CRUD)
- list price, negotiated price, total discount and discount % entered on every line

Decisions from the user:
- **Linked pricing.** All four line values can be edited. Editing negotiated price, discount or discount % recalculates the other two.
- **Lines are products.** Each line has a Product2 lookup and a **quantity**.
- **Placement.** Users work with quotes from the **Salesforce Home page**.
- **Markups allowed.** Negotiated price may exceed list price, which gives a negative discount. Only negative prices and a quantity of 0 or less are blocked.

Findings from exploring the repo and org:
- The target org `LATEST_OCT_26_PLAYGROUND` has **no custom objects**, and nothing from this repo has been deployed there.
- The standard `Quote` object is **not enabled**, so the names `Quote__c` and "Quote" don't collide with anything. Product2 and Pricebook2 exist.
- Existing pattern: Controller → Service → Selector, with `AuraHandledException` plus `setMessage()` (see `force-app/main/default/classes/CaseSimilarityController.cls:36`).
- **Root cause of the baseline Jest failures:** the existing tests query `element.querySelector(...)` instead of `element.shadowRoot.querySelector(...)` (for example `lwc/caseSimilarityFinder/__tests__/caseSimilarityFinder.test.js:42`). The new tests will use `shadowRoot`. Fixing the old tests is out of scope.
- `.forceignore` ignores any file named `package.xml`, so the deploy manifest gets a different name.

---

## 1. Data model

```
 ┌──────────────┐        ┌──────────────┐
 │   Account    │        │ Opportunity  │
 └──────┬───────┘        └──────┬───────┘
        │ 0..1 (Lookup)         │ 0..1 (Lookup)
        ▼                       ▼
 ┌──────────────────────────────────────────────┐
 │ Quote__c   (OWD: Private)                     │
 │  Name (Text 80, "Quote Name")                 │
 │  Account__c, Opportunity__c (Lookups)         │
 │  Status__c (Draft/Presented/Accepted/Rejected)│
 │  Expiration_Date__c (Date)                    │
 │  Total_List_Price__c       ROLLUP SUM(line)   │
 │  Total_Negotiated_Price__c ROLLUP SUM(line)   │
 │  Total_Discount__c         FORMULA            │
 │  Discount_Percent__c       FORMULA            │
 │  Line_Count__c             ROLLUP COUNT       │
 └──────────────────┬───────────────────────────┘
                    │ 1 ── * (Master-Detail, cascade delete)
                    ▼
 ┌──────────────────────────────────────────────┐        ┌───────────┐
 │ Quote_Line__c (OWD: ControlledByParent)       │  *──1  │ Product2  │
 │  Name (AutoNumber QL-{00000})                 │───────►│ (standard)│
 │  Quote__c (Master-Detail)                     │ Lookup,└───────────┘
 │  Product__c (Lookup, required, Restrict del)  │ required
 │  Quantity__c         Number(12,2)    input    │
 │  List_Price__c       Currency(16,2)  unit in  │
 │  Negotiated_Price__c Currency(16,2)  unit in  │
 │  Total_List_Price__c       FORMULA Qty×List   │
 │  Total_Negotiated_Price__c FORMULA Qty×Neg    │
 │  Total_Discount__c         FORMULA TL − TN    │
 │  Discount_Percent__c       FORMULA (%)        │
 └──────────────────────────────────────────────┘
```

**Why this shape:**
- Only the unit **list price** and **negotiated price** are stored. Discount and discount % are formulas, so the stored values can never contradict each other.
- The "linked" editing happens in the UI. An edited discount or % is converted to a negotiated price before saving.
- The header totals are **roll-up summaries** of deterministic line formulas, which roll-ups allow. They need no trigger, and the same numbers appear in reports and list views.

**Formulas:**
- Line `Discount_Percent__c` = `IF(List_Price__c = 0, 0, (List_Price__c - Negotiated_Price__c) / List_Price__c)`
- Header `Discount_Percent__c` = `IF(Total_List_Price__c = 0, 0, Total_Discount__c / Total_List_Price__c)`
- Header `Total_Discount__c` = `Total_List_Price__c - Total_Negotiated_Price__c`

**Validation rules on Quote_Line__c:** `Quantity__c > 0`, `List_Price__c >= 0`, `Negotiated_Price__c >= 0`. There's no upper bound, because markups are allowed.

Every object and field gets a `<description>`, following the repo convention.

## 2. Metadata to create
Paths are under `force-app/main/default/`.

| Type | Items |
|---|---|
| Custom objects | `objects/Quote__c/` and `objects/Quote_Line__c/`, each with the fields, validation rules and list view `All` |
| Permission set | `permissionsets/Quote_Manager_User`: CRUD on both objects, FLS on the editable fields, read-only on formula and roll-up fields, read on Product2, Account and Opportunity, and Apex access to `QuoteManagerController`. Required fields and the master-detail field are left out, because the platform rejects FLS entries on them. |
| Custom labels | `QuoteManager_*` entries added to `labels/CustomLabels.labels-meta.xml` for card titles, buttons, column headings, empty states and toasts |
| FlexiPage | `flexipages/Quote_Manager_Home.flexipage-meta.xml` (type `HomePage`) containing `c:quoteManager` |
| Seed script | `scripts/apex/seedQuoteProducts.apex`, which creates a few active Product2 records for the demo |

## 3. Apex classes
All classes are `with sharing` (selectors are `inherited sharing`). Methods have ApexDoc comments and stay at 25 lines or fewer. SOQL uses `WITH USER_MODE` and DML uses `AccessLevel.USER_MODE`.

`USER_MODE` replaces the repo's older `SECURITY_ENFORCED` because it also enforces CRUD and FLS on DML. That decision gets recorded in `README-TASK.md`. The LWC never sends free text to Apex; inputs are Ids and numbers. Quotes are created through LDS (`lightning-record-edit-form`), so `escapeSingleQuotes` and `escapeHtml4` have nothing to sanitize. That's noted too.

| Class | Responsibility |
|---|---|
| `Quote_Selector` | `selectRecent(Integer limitSize)` for the Home page quote list, ordered by LastModifiedDate. `selectById(Id)` returns the header and roll-ups. |
| `Quote_Line_Selector` | `selectByQuoteId(Id)` returns lines with `Product__r.Name`, capped by LIMIT 500. `selectByIds(Set<Id>)` is used for ownership checks. |
| `QuoteLineInput` | A DTO the LWC sends: `id`, `productId`, `quantity`, `listPrice`, `negotiatedPrice`. It's an explicit whitelist, so the client can't set `Quote__c` or other fields. |
| `QuoteManager_Service` | `getQuotes()`, `getQuoteDetail(quoteId)` (header plus lines in a `QuoteDetail` wrapper), `saveLines(quoteId, List<QuoteLineInput>)` (upsert), `deleteLines(quoteId, Set<Id>)` and `deleteQuote(quoteId)`. Before any DML, it checks that every existing line Id belongs to `quoteId`, and throws `QuoteManagerException` if one doesn't. |
| `QuoteManagerController` | `@AuraEnabled` methods that only delegate. Errors are wrapped with `AuraHandledException` plus `setMessage()`, the same pattern as Case Similarity. `getQuotes` is cacheable; the rest aren't. |

There's no trigger: roll-ups and formulas cover all the aggregation.

## 4. LWCs
Each component lives in `lwc/<name>/`, takes its text from custom labels, and avoids reassigning `@api` properties. The existing components break that lint rule; these won't. Components will be built with the `experience-lwc:experience-lwc-generate` and `experience-lwc:experience-lwc-base-components-integrate` skills.

| Component | Role |
|---|---|
| `quoteCalculations` | A service module with no template. It holds pure functions: `recalcLine(line, editedField, value)` for the linked editing (below), `computeTotals(lines)` for the header, and percent and 2-decimal rounding helpers. Both the table and the header use it, so unsaved edits update the header live. |
| `quoteManager` | The container, exposed to `lightning__HomePage` and `lightning__AppPage`. It shows a quote list (combobox or datatable of recent quotes), plus New, Edit and Delete for the quote, and holds the selected quote's lines. It handles Save and Cancel for inline edits, deletes behind a `LightningConfirm`, shows toasts, and refreshes after every write. |
| `quoteSummary` | The header. It receives `@api totals` and shows total list price, total negotiated price, total discount and discount % (plus line count) as `lightning-formatted-number` tiles. |
| `quoteLineTable` | A `lightning-datatable` with inline editing for Quantity, Unit List Price, Unit Negotiated Price, Line Discount and Discount %, and read-only Product and line totals. Each `cellchange` goes through `recalcLine`. Row actions are Edit and Delete. It sends `save`, `cancel`, `rowedit`, `rowdelete` and `draftschange` events to the parent. |
| `quoteLineModal` | A `LightningModal` for adding or editing a line. It uses `lightning-record-picker` on Product2 (filtered to `IsActive = true`), because the datatable can't edit lookups inline, plus quantity and the four linked price inputs. |
| `quoteEditModal` | A `LightningModal` wrapping `lightning-record-edit-form` for creating and editing `Quote__c`, following the persona guidance. |

**How the linked editing works in `recalcLine`:**
- Editing negotiated price stores it directly.
- Editing line discount D sets negotiated price = list − D ÷ qty.
- Editing discount % P sets negotiated price = list × (1 − P ÷ 100).
- Editing quantity or list price keeps the unit negotiated price, and the totals and % are recalculated.
- Results are rounded to 2 decimals.
- If list price is 0, the % shows 0 and can't be edited.

After the build, the components get a review pass with `experience-lwc:experience-accessibility-validate` and `experience-lwc:experience-lwc-security-validate`.

## 5. Tests

**Apex.** Written with `platform-apex-test-generate`. Data comes from a `QuoteTestDataFactory` test utility, and each class gets its own `*_Test` class:
- `Quote_Selector_Test`: ordering, limit, and that `selectById` returns the roll-ups.
- `Quote_Line_Selector_Test`: lines are filtered by quote and include `Product__r.Name`.
- `QuoteManager_Service_Test`:
  - Insert and update through `saveLines`, then assert the line formulas and header roll-ups, including a markup line with a negative discount and a list price of 0.
  - Delete lines, and confirm the header recalculates.
  - Deleting a quote cascades to its lines.
  - Passing a line Id from a different quote throws an error.
  - Each validation rule blocks bad data: quantity ≤ 0 and negative prices.
  - Saving 200 lines in bulk.
  - `System.runAs` a user without `Quote_Manager_User` and confirm USER_MODE raises an error.
- `QuoteManagerController_Test`: delegation works, and service exceptions reach the client as an `AuraHandledException` with a message.

The target is at least 90% coverage per class.

**Jest.** Tests live in `lwc/<name>/__tests__/` and use `element.shadowRoot`. Apex imports and `lightning/modal` / `LightningConfirm` are mocked.
- `quoteCalculations.test.js`: every edit path, quantity changes, list price of 0, markups, rounding and `computeTotals`.
- `quoteSummary.test.js`: renders formatted totals and handles empty or zero values.
- `quoteLineTable.test.js`: columns are editable, a cell change triggers a recalculation and sends `draftschange`, and row actions send the right events.
- `quoteManager.test.js`: loads quotes, selecting one loads its detail, saving calls `saveQuoteLines` with recalculated values, delete with confirmation, an error toast, and the empty state.
- `quoteLineModal.test.js` and `quoteEditModal.test.js`: inputs, closing with a result, and cancel.

Risk: if this version of `sfdx-lwc-jest` doesn't stub `lightning-record-picker`, I'll add a `moduleNameMapper` stub in `jest.config.js`.

## 6. Deploying to `LATEST_OCT_26_PLAYGROUND`
Uses the `platform-deploy-validate` and `platform-metadata-deploy` skills. DevOps Center isn't set up for this org, so the `dx-devops` skills don't apply to a direct deploy. They're available if you later want work items and pipeline promotion.

I'll use a scoped manifest, `manifest/quote-manager.xml`. It can't be named `package.xml`, because `.forceignore` excludes that name. A scoped manifest also stops the deploy from pulling in the never-deployed Account Map and Case Similarity code, and avoids the `reactlist` bundle issue.

The manifest lists the two CustomObjects (with their fields, validation rules and list views), the PermissionSet, the new ApexClasses, the LightningComponentBundles, the `QuoteManager_*` CustomLabels and the FlexiPage.

```bash
# 1. Validate
sf project deploy start --manifest manifest/quote-manager.xml --dry-run \
  --test-level RunSpecifiedTests --tests Quote_Selector_Test --tests Quote_Line_Selector_Test \
  --tests QuoteManager_Service_Test --tests QuoteManagerController_Test --target-org LATEST_OCT_26_PLAYGROUND
# 2. Deploy (same command without --dry-run)
# 3. Access and data
sf org assign permset --name Quote_Manager_User --target-org LATEST_OCT_26_PLAYGROUND
sf apex run --file scripts/apex/seedQuoteProducts.apex --target-org LATEST_OCT_26_PLAYGROUND
# 4. Activate the Home page
#    Assigning a page as the org-default Home page isn't something this deploy can set, so it's
#    one manual step: Lightning App Builder → Quote_Manager_Home → Activation → Org Default.
#    (Alternative: assign it to a single app with a profile action override.)
```

## 7. Build order
1. Objects and fields
2. Permission set
3. `QuoteLineInput` DTO
4. Selectors
5. Service
6. Controller
7. Apex tests
8. Labels
9. `quoteCalculations`, then the child LWCs, then `quoteManager`
10. Jest tests
11. FlexiPage
12. Manifest and deploy

Afterwards I'll update `README-TASK.md`, recording decisions and created files with links to the docs, as the copilot-instructions require. I'll also update `CLAUDE.md` with a Quote Manager section and change "three independent features" to four.

Note: the `salesforce-api-context` and `salesforce-metadata-experts` MCP servers timed out on connect. If they're still down during implementation, metadata XML gets checked by the dry-run deploy instead.

## 8. Verification
- `npx sfdx-lwc-jest -- quote`: all new Jest tests pass.
- `npx eslint force-app/main/default/lwc/quote*`: clean. The repo-wide lint baseline has unrelated errors.
- `npx prettier --check` on the new files.
- Dry-run deploy succeeds, then the real deploy succeeds.
- `sf apex run test --class-names QuoteManager_Service_Test ... --code-coverage --result-format human --wait 10`: all tests pass, with at least 90% coverage per class.
- Manual smoke test on the Home page:
  1. Create a quote.
  2. Add 3 lines with different products.
  3. Edit discount % on one line and confirm negotiated price and line discount update immediately, along with the header.
  4. Enter a markup line and confirm the discount is negative.
  5. Save, reload, and confirm the header matches the roll-ups.
  6. Delete a line.
  7. Delete the quote.
