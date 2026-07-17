@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Update Status of Prepayment'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_PREPAY_STATUS_UPDATE as select from ztb_prepy_status
{
    key sap_uuid              as SapUuid,
        prepayso              as PrepaySalesorder,
        prepaysoitem          as PrepaySalesorderitem,
        delvso                as DelvSalesorder,
        delvsoitem            as DelvSalesorderitem,
        billingplanitem       as Billingplanitem,
        socurrency            as Socurrency,

        @Semantics.amount.currencyCode: 'socurrency'
        appliedamount         as Appliedamount,

        accountingdocument    as AccountingDocument,
        fiscalyear            as FiscalYear,
        companycode           as CompanyCode,
        scenario              as Scenario,
        iotype                as IOType,
        isjeposted            as Isjeposted,
        isbillingplanposted   as Isbillingplanposted,
        isconsumptiontableupdated as Isconsumptiontableupdated,
        reversalflag          as ReversalFlag,
        writeoffflag          as WriteoffFlag,
        message as Message,
        changedatetime        as Changedatetime,
        @Semantics.user.lastChangedBy: true
        lastchangedby         as Lastchangedby
}
