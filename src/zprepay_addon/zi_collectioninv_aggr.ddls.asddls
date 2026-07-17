@ClientHandling: {
  type: #CLIENT_DEPENDENT,          // required
  algorithm: #SESSION_VARIABLE     // or #PARAMETER
}
@EndUserText.label: 'Aggregate the Collection Invoice to a line'
define table function ZI_COLLECTIONINV_AGGR

returns {
    RCLNT                      : mandt;
    DeliverySO       : abap.char(10);
    DeliverySOItem   : abap.char(6);
    BillingDocument : abap.char(10);
    AccDocList   : abap.string(1000);
  
}
implemented by method ZCL_DELVSO_COLL=>GET_DATA;