# Quote Manager handoff

A custom quoting screen for an org without a CPQ licence, built and deployed from `sf-and-ai` on 2026-11-10. This note is for picking the work up in a new repo. The design detail is in `QUOTE_MANAGEMENT_PLAN.md`; the requirements are in `PROJECT_REQUIREMENTS.md`.

## Status
- **Deployed:** to `LATEST_OCT_26_PLAYGROUND`, a Trailhead Playground. All 91 components went in, the 30 Apex tests pass, and each Apex class has 100% coverage.
- **Local tests:** the 46 Jest tests in the 6 `quote*` suites pass, and ESLint is clean on `lwc/quote*`.
- **Org setup:** `Quote_Manager_User` is assigned to the deploying user, and 5 demo products are seeded (`Quote Demo - ...`).
- **Git:** none of this is committed in `sf-and-ai`.

## Decisions (agreed with you during planning)
| Topic | Decision |
|---|---|
| Line pricing | Linked. Only **unit list price** and **unit negotiated price** are stored. Line totals, discount and discount % are formula fields. In the LWC, editing negotiated price, line discount or discount % rewrites the negotiated price, using `quoteCalculations.recalcLine`. |
| Line contents | Product2 lookup plus **quantity**. Line totals are quantity × unit price. |
| Placement | **Home page**, through the `Quote_Manager_Home` FlexiPage. The component also supports `lightning__AppPage`. |
| Markups | Allowed. Negotiated price can exceed list price, which gives a negative discount. Validation blocks only a quantity of 0 or less and negative prices. |
| Header totals | Roll-up summaries (`Total_List_Price__c`, `Total_Negotiated_Price__c`, `Line_Count__c`) plus formulas (`Total_Discount__c`, `Discount_Percent__c`). There's no trigger. While lines are being edited, the LWC shows totals it calculates itself. |
| Security | `WITH USER_MODE` / `AccessLevel.USER_MODE`. The LWC sends Apex only Ids and numbers, through the `QuoteLineInput` DTO, so no `escapeHtml4` / `escapeSingleQuotes` is needed. |
| Architecture | Controller → Service → Selector in plain Apex, with no fflib. Errors are an `AuraHandledException` with `setMessage()`. |

## Files to copy
Paths are under `force-app/main/default/` unless shown otherwise.
- **Objects:** `objects/Quote__c/` and `objects/Quote_Line__c/`. These include 18 fields, 4 validation rules and the `All` list views.
- **Permission set:** `permissionsets/Quote_Manager_User.permissionset-meta.xml`.
- **Apex:** `classes/Quote*`: `Quote_Selector`, `Quote_Line_Selector`, `QuoteLineInput`, `QuoteManager_Service`, `QuoteManagerController`, `QuoteTestDataFactory` and the 4 `*_Test` classes, each with its `.cls-meta.xml`.
- **LWCs:** `lwc/quoteCalculations`, `quoteManager`, `quoteSummary`, `quoteLineTable`, `quoteLineModal` and `quoteEditModal`, each with `__tests__/`.
- **Home page:** `flexipages/Quote_Manager_Home.flexipage-meta.xml`.
- **Labels:** **only** the 47 `QuoteManager_*` entries in `labels/CustomLabels.labels-meta.xml`. That file also holds the Case Similarity labels.
- **Repo root:**
  - `manifest/quote-manager.xml`
  - `scripts/apex/seedQuoteProducts.apex`
  - `jest-mocks/lightning/modal.js`
  - `QUOTE_MANAGEMENT_PLAN.md`
  - `PROJECT_REQUIREMENTS.md`
  - this file
- **Config to recreate:**
  - `jest.config.js` needs `moduleNameMapper: { '^lightning/modal$': '<rootDir>/jest-mocks/lightning/modal.js' }`, because sfdx-lwc-jest doesn't stub `lightning/modal`.
  - `sfdx-project.json` needs API 65.0.
  - Dev dependencies: `@salesforce/sfdx-lwc-jest` ^7, `eslint` ^9 and `@lwc/eslint-plugin-lwc`, plus Prettier with 2-space indent.

## Deploy runbook (for a fresh org)
The order matters. Every `sf` command needs `--target-org <alias>`.
1. **Deploy the two objects alone:** a manifest with just `CustomObject: Quote__c, Quote_Line__c`.
2. **Deploy `Quote_Manager_User` without its `<classAccesses>` block**, because `QuoteManagerController` doesn't exist in the org yet. Then run `sf org assign permset --name Quote_Manager_User`.
   - Why: the Apex runs in user mode, and newly deployed fields give the admin profile no field-level security. Unless the permission set already exists and is assigned, the tests fail with errors like "No such column 'Status__c'". Assigning it inside the tests isn't enough on a first deploy.
3. **Deploy everything else with tests:** `sf project deploy start --manifest manifest/quote-manager.xml --test-level RunSpecifiedTests --tests Quote_Selector_Test --tests Quote_Line_Selector_Test --tests QuoteManager_Service_Test --tests QuoteManagerController_Test`. This also restores the class access on the permission set.
4. **Load demo products:** `sf apex run --file scripts/apex/seedQuoteProducts.apex`. It's safe to re-run, because it skips products that already exist.
5. **Manual step:** Lightning App Builder → `Quote_Manager_Home` → Activation → Org Default. The deploy can't set this.

## Gotchas found along the way
- **Product2 lookup:** it can't use the Restrict delete option, and a required lookup can't use SetNull. So `Quote_Line__c.Product__c` is optional at field level, and the `Product_Required` validation rule enforces it. Deleting a product clears it from the quote lines that used it.
- **Required fields in permission sets:** a permission set can't include field permissions for required or master-detail fields. That's why `Quantity__c`, `List_Price__c`, `Negotiated_Price__c` and `Quote__c` are missing from `Quote_Manager_User`, and that's correct.
- **Percent units:** the `Discount_Percent__c` formulas return percent units from Apex (15 = 15%). `lightning-datatable` `percent` columns expect a fraction (0.15), so `quoteCalculations` converts between them.
- **Salesforce plugin deploy gate:** it treats a Playground as Production and blocks deploys, even dry runs. Prefix the command with `CONFIRM_PROD=1` once you've confirmed it's a non-production org. The gate also fires on any shell command whose text mentions deploy commands.
- **`reactlist` bundle:** in `sf-and-ai` it breaks every deploy method, including manifest and metadata deploys. It isn't part of this work, so leave it out of the new repo.
- **Validation runs and new fields:** a validation-only deploy (`--dry-run`) of new fields plus a new permission set still fails the user-mode tests. Use the step order in the runbook instead.

## Open items
- [ ] Activate `Quote_Manager_Home` as the org-default Home page.
- [ ] Manual test in the org:
  1. Create a quote.
  2. Add 3 product lines.
  3. Edit a line's discount % and check that its negotiated price and the header update immediately.
  4. Add a markup line and check the discount shows as negative.
  5. Save, reload, and check the header matches.
  6. Delete a line.
  7. Delete the quote.
- [ ] Run the accessibility and security reviews on `lwc/quote*` (the `experience-lwc:experience-accessibility-validate` and `experience-lwc:experience-lwc-security-validate` skills). They haven't been run yet.
- [ ] Check `QuoteManager_Service_Test`'s runAs tests in the new org. They expect the `Standard User` profile to have no access to `Quote__c`.
- [ ] Possible later improvements:
  - Copy a product's standard price from Pricebook2 as the default list price.
  - A Quote record page.
  - A configurable quote-list limit (currently fixed at 50).
  - A limit on lines per quote (currently 500 per query).
