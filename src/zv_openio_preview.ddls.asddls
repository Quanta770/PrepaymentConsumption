@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Preview view for selected open io rows'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZV_OPENIO_PREVIEW 
as select from ZI_OPENIO_ROWS_MATCHING
{
    key SAPUUID,
    @Consumption.filter: {
        mandatory: true,
        hidden: false
    }
    SESSIONID,
    PREPAYMENTREQNUMPREPAYMENT,
    PREPAYMENTSO,
    PREPAYMENTSOITEM,
    PREPAYMENTSALESORG,
    PREPAYMENTSOLDTO,
    PREPAYMENTSCENARIOPY,
    PREPAYMENTCURRENCY,
    @Semantics.amount.currencyCode: 'PREPAYMENTCURRENCY'
    PREPAYMENTNETAMOUNT,
    @Semantics.amount.currencyCode: 'PREPAYMENTCURRENCY'
    PREPAYMENTREMAININGAMOUNT,
    PREPAYDOCDATE,
    DELVSOSALESDOCUMENT,
    DELVSOSALESDOCUMENTITEM,
    DELVSOSALESORG,
    DELVSOSOLDTO,
    DELVSOSCENARIO,
    DELVSOCURRENCY,
    @Semantics.amount.currencyCode: 'DELVSOCURRENCY'
    DELVSONETAMOUNT,
    @Semantics.amount.currencyCode: 'DELVSOCURRENCY'
    DELVREMAININGAMOUNT,
    DELVDOCDATE,
    @Semantics.amount.currencyCode: 'DELVSOCURRENCY'
    DELVSOAMOUNT_ADJ
}
