@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Get Collection Invoice Details'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_BILLING_GETCOLLINV as select from ZI_COLLECTIONINV_AGGR

{
    
 key DeliverySO,
 key DeliverySOItem,
  BillingDocument,
  AccDocList
}
