@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Prepayment process log - interface'
@Metadata.allowExtensions: true
define root view entity ZI_PREPAY_PROCESS_LOG
  as select from ztb_prepay_log
  composition [1..*] of ZI_PREPAY_PROCESS_STEP as _ProcessStep
{
  key log_id                     as LogId,
      flow_type                  as FlowType,
      logged_at                  as LoggedAt,
      logged_by                  as LoggedBy,
      status                     as Status,
      message_text               as MessageText,
      delivery_so                as DeliverySo,
      delivery_so_item           as DeliverySoItem,
      prepayment_so              as PrepaymentSo,
      prepayment_so_item         as PrepaymentSoItem,
      company_code               as CompanyCode,
      accounting_document        as AccountingDocument,
      fiscal_year                as FiscalYear,

      cast(
        case status
          when 'S' then 3
          when 'P' then 2
          when 'E' then 1
          else 0
        end as abap.int1 )       as StatusCriticality,

      cast(
        case status
          when 'P' then 'Pending'
          when 'S' then 'Success'
          when 'E' then 'Error'
          else ''
        end as abap.char( 20 ) ) as StatusText,

      _ProcessStep
}
group by
  log_id,
  flow_type,
  logged_at,
  logged_by,
  status,
  message_text,
  delivery_so,
  delivery_so_item,
  prepayment_so,
  prepayment_so_item,
  company_code,
  accounting_document,
  fiscal_year
