@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Prepayment log - write access'
define root view entity ZI_PREPAY_LOG_WRITE
  as select from ztb_prepay_log
{
  key log_id              as LogId,
      correlation_id      as CorrelationId,
      flow_type           as FlowType,
      step_seq            as StepSeq,
      step_name           as StepName,
      status               as Status,
      http_method          as HttpMethod,
      http_status          as HttpStatus,
      uri                  as Uri,
      response_body        as ResponseBody,
      message_text         as MessageText,
      delivery_so          as DeliverySo,
      delivery_so_item     as DeliverySoItem,
      prepayment_so        as PrepaymentSo,
      prepayment_so_item   as PrepaymentSoItem,
      company_code         as CompanyCode,
//      client_process_id    as ClientProcessId,
      accounting_document  as AccountingDocument,
      fiscal_year          as FiscalYear,
      logged_at            as LoggedAt,
      logged_by            as LoggedBy
}
