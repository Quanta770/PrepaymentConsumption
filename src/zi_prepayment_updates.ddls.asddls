@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface view of Prepay Updates'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_Prepayment_Updates as select from ztb_prepayment_c
{
    key sap_uuid          as sap_uuid,
    key delvsosalesdocument as delvsosalesdocument,
    key delvsosalesdocumentitem as delvsosalesdocumentitem,
    key prepaymentrequestd as prepaymentrequestd,
    prepaymentrequestp as prepaymentrequestp,
    changedatetime as changedatetime,
    prepaymentso as prepaymentso,
    prepaymentsoitem as prepaymentsoitem,
    lastchangedby as lastchangedby,
    status as status,
    message as message,
    sessionid as sessionid
    
}
