@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Delivery SO Billed'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_DELIVERYSO_BILLED
  as select from    I_SDDocumentMultiLevelProcFlow as SDflow
    left outer join I_BillingDocumentItem          as Billitem on  SDflow.SubsequentDocument     = Billitem.BillingDocument
                                                               and SDflow.SubsequentDocumentItem = Billitem.BillingDocumentItem
    left outer join I_BillingDocument              as Billhdr  on Billhdr.BillingDocument = Billitem.BillingDocument
{
  key SDflow.PrecedingDocument      as SalesDocument,
  key SDflow.PrecedingDocumentItem  as SalesDocumentItem,
      SDflow.PrecedingDocumentCategory,
      SDflow.SubsequentDocument     as BillingDocument,
      SDflow.SubsequentDocumentItem as BillingDocumentItem,
      SDflow.SubsequentDocumentCategory,
      Billhdr.ReversalReason

}
where
      SDflow.PrecedingDocumentCategory   = 'C'
  and SDflow.SubsequentDocumentCategory  = 'M'
  and Billhdr.BillingDocumentIsCancelled is initial
