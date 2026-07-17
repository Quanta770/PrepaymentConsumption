@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption view Prepayment Updates'
@Metadata.ignorePropagatedAnnotations: false
define root view entity ZC_Prepayment_Updates as projection on ZI_Prepayment_Updates
{
    key sap_uuid ,
    key delvsosalesdocument,
    key delvsosalesdocumentitem,
    key prepaymentrequestd,
    prepaymentrequestp,
        changedatetime,
    prepaymentso,
    prepaymentsoitem,
    lastchangedby,
    status,
    message,
    sessionid
}
