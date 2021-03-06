class Sms::OrdersController < ApplicationController
  skip_before_action *ADMIN_FILTERS, only: [:notify, :notify_verify, :error_notify]
  before_action :set_sms_order, only: [:show, :edit, :update, :destroy, :cancel]

  before_action do
    @partialLeftNav = "/layouts/partialLeftSys"
  end

  def index
    if params[:search].present? && params[:search][:status_eq].present?
      @search = current_site.sms_orders.where(["status not in (?) and plan_type = ? ", [SmsOrder::F_DELETE, SmsOrder::T_DELETE], SmsOrder::BUY]).order("sms_orders.id DESC").search(params[:search])
    else
      @search = current_site.sms_orders.where(["status not in (?)", [SmsOrder::F_DELETE, SmsOrder::T_DELETE]]).order("sms_orders.id DESC").search(params[:search])
    end
    @sms_orders = @search.result.page(params[:page])
  end

  def new
    @sms_order = current_site.sms_orders.new(plan_id: 1)
    render layout: 'application_pop'
  end

  def create
    @sms_order = current_site.sms_orders.new(params[:sms_order])
    if @sms_order.save
      @payment = @sms_order.payment!

      render inline: "<script>window.parent.location.href = '#{sms_orders_path}';</script>"
      return
    else
      flash[:alert] = "购买失败"
      render action: 'new', layout: 'application_pop'
    end
  end

  def destroy
    if @sms_order.delete!
      redirect_to :back, notice: '删除成功'
    else
      redirect_to :back, alert: '删除失败'
    end
  end

  def cancel
    if @sms_order.cancel!
      redirect_to :back, notice: '取消成功'
    else
      redirect_to :back, alert: '取消失败'
    end
  end

  def alipayapi
    @sms_order = SmsOrder.pending.find params[:id]
    @payment = Payment.pending.find(params[:payment_id])

    @data = @sms_order.options_pay_for(@payment)
    @sign = @sms_order.generate_md5(@sms_order.sort_str(@data))

    render layout: false
  rescue => error
    SiteLog::Alipay.add("alipay request faied :#{error}")
    render text: "请求失败:#{error}"
  end

  def callback
    SiteLog::Alipay.add("alipay callback params:#{params}")

    payment = Payment.where(out_trade_no: params[:out_trade_no]).first
    paymentable =  payment.try(:paymentable)

    if paymentable.present? && params['is_success'] == 'T'
      redirect_to sms_orders_path, notice: '购买短信套餐成功'
    else
      redirect_to sms_orders_path, alert: '购买短信套餐失败'
    end
  end

  def notify
    SiteLog::Alipay.add("alipay notify params:#{params}")

    payment = Payment.where(out_trade_no: params[:out_trade_no]).first
    paymentable =  payment.try(:paymentable)

    if notify_verify(params['notify_id'])
      payment.update_attributes(trade_status: 'TRADE_SUCCESS', trade_no: params[:trade_no], status: Payment::SUCCESS, order_msg: params.to_s)
      paymentable.set_to_succeed(true) if paymentable

      render text: 'success'
    else
      paymentable.set_to_succeed(false) if paymentable

      render text: 'fail'
    end
  rescue => error

    SiteLog::Alipay.add("alipay notify error:#{error}")
    render text: 'fail'
  end

  def notify_verify(notify_id)
    begin
      RestClient.get("https://mapi.alipay.com/gateway.do?service=notify_verify&partner=#{SmsOrder::ALIPAY_ID}&notify_id=#{notify_id}")
    rescue
      'false'
    end
  end

  def error_notify
    SiteLog::Alipay.add("alipay error_notify params:#{params}")
    render text: 'error'
  end

  def set_sms_order
    @sms_order = current_site.sms_orders.find(params[:id])
  end

end
