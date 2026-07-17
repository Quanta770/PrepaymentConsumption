@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sum of open amount for prepayment sales order'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_PREPAY_SO_OPEN_AMT 
as select from I_JournalEntryItem as item
inner join I_OperationalAcctgDocItem as Opp on Opp.AccountingDocument = item.AccountingDocument
                                            and Opp.AccountingDocumentItem = item.AccountingDocumentItem
                                            and Opp.FiscalYear = item.FiscalYear
                                            and Opp.CompanyCode = item.CompanyCode
                                            and Opp.SpecialGLCode is not initial
                                            and Opp.Customer is not initial
left outer join I_SalesDocument as SalesDoc on SalesDoc.SalesDocument = item.SalesDocument
                                            and SalesDoc.YY1_PrepaymentScenario_SDH is not null
                                            and SalesDoc.YY1_PrepaymentScenario_SDH <> ''
                                            and SalesDoc.YY1_PrepaymentScenario_SDH is not initial
left outer join I_SalesDocumentItem as SalesDocItem on SalesDocItem.SalesDocument = item.SalesDocument
                                            and SalesDocItem.SalesDocumentItem = item.SalesDocumentItem
{
    key item.SalesDocument,
    key item.SalesDocumentItem,
    Opp.TransactionCurrency,
    @Semantics.amount.currencyCode: 'TransactionCurrency'
    case when SalesDoc.YY1_PrepaymentScenario_SDH = 'D1' or SalesDoc.YY1_PrepaymentScenario_SDH = 'D2'
    then cast(
      sum( get_numeric_value(Opp.AmountInTransactionCurrency) - get_numeric_value(Opp.TaxAmount) ) * -1
      /
      ( 1 + (
          max(
            cast(
              case when SalesDocItem.YY1_PrepayTaxRate_SDI is null
                     or ltrim(SalesDocItem.YY1_PrepayTaxRate_SDI, ' ') = ''
                     or lower(ltrim(SalesDocItem.YY1_PrepayTaxRate_SDI, ' ')) = 'null'
                   then '0'
                   else SalesDocItem.YY1_PrepayTaxRate_SDI
              end as abap.dec(5,2)
            )
          ) / 100
        )
      )
      as abap.dec(23,2)
    )
    else
    cast(
      sum( get_numeric_value(Opp.AmountInTransactionCurrency) - get_numeric_value(Opp.TaxAmount) ) * -1
      as abap.dec(23,2)
    ) end as PrepayAmount
//     cast(
//          sum( get_numeric_value(Opp.AmountInTransactionCurrency) - get_numeric_value(Opp.TaxAmount) ) * -1
//          as abap.dec(23,2)
//        ) as PrepayAmount
}
where item.SpecialGLCode is not initial
and item.Customer is not initial
and item.Ledger = '0L'
and item.SalesDocument is not initial
and (item.AccountingDocumentType = 'D8' or item.AccountingDocumentType = 'DZ' or item.AccountingDocumentType = 'D9')

group by 
item.SalesDocument, 
item.SalesDocumentItem,
Opp.TransactionCurrency,
SalesDoc.YY1_PrepaymentScenario_SDH
