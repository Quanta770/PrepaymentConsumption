@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sum of all prepayment credit note amount for scenario B'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_Prepayment_CN_AMT
  as select from I_SalesDocItmSubsqntProcFlow as flow
  inner join I_CreditMemoRequestItem as cmr on flow.SubsequentDocument = cmr.CreditMemoRequest
                                                  and flow.SubsequentDocumentItem = cmr.CreditMemoRequestItem
{
    flow.SalesDocument,
    flow.SalesDocumentItem,
    cmr.TransactionCurrency,
    @Semantics.amount.currencyCode: 'TransactionCurrency'
    cast(
      sum( get_numeric_value(cmr.NetAmount))
      as abap.dec(23,2)
    ) as CreditNoteAmount
}
where 
      flow.SubsequentDocumentCategory = 'K'
group by 
    flow.SalesDocument, 
    flow.SalesDocumentItem, 
    cmr.TransactionCurrency

    // note this is for scenario B prepayment credit note amount
