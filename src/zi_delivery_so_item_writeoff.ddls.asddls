@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Delivery SO Item Billing Plan WriteOff'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_DELIVERY_SO_ITEM_WRITEOFF as select from I_SlsOrderItemBillingPlanItem
{
    SalesOrder,
    SalesOrderItem,
    BillingPlan,
    max(
      case
        when BillingBlockReason = 'Z1' then 'X'
        else null
      end
    ) as HasWriteOff
}group by
    SalesOrder,
    SalesOrderItem,
    BillingPlan;
