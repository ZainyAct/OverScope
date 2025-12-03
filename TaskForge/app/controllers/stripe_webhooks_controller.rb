class StripeWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!

  def create
    payload = request.body.read
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']
    endpoint_secret = ENV['STRIPE_WEBHOOK_SECRET']

    # Stripe webhook verification (when Stripe gem is configured)
    if endpoint_secret.present? && defined?(Stripe)
      begin
        event = Stripe::Webhook.construct_event(payload, sig_header, endpoint_secret)
        handle_stripe_event(event)
      rescue JSON::ParserError => e
        render json: { error: 'Invalid payload' }, status: :bad_request
        return
      rescue Stripe::SignatureVerificationError => e
        render json: { error: 'Invalid signature' }, status: :bad_request
        return
      end
    else
      # Fallback for development/testing without Stripe keys
      begin
        event_data = JSON.parse(payload)
        event_type = event_data['type'] || params[:type]
        object_data = event_data['data']&.dig('object') || event_data['object'] || {}
        handle_json_event(event_type, object_data)
      rescue JSON::ParserError
        render json: { error: 'Invalid payload' }, status: :bad_request
        return
      end
    end

    render json: { received: true }, status: :ok
  end

  private

  def handle_stripe_event(event)
    case event.type
    when 'customer.subscription.created', 'customer.subscription.updated'
      handle_subscription_event(event.data.object)
    when 'customer.subscription.deleted'
      handle_subscription_deleted(event.data.object)
    when 'invoice.paid'
      handle_invoice_paid(event.data.object)
    end
  end

  def handle_json_event(event_type, object_data)
    case event_type
    when 'customer.subscription.created', 'customer.subscription.updated'
      handle_subscription_event_hash(object_data)
    when 'customer.subscription.deleted'
      handle_subscription_deleted_hash(object_data)
    when 'invoice.paid'
      handle_invoice_paid_hash(object_data)
    end
  end

  def handle_subscription_event(subscription)
    org = Organization.find_by(stripe_customer_id: subscription.customer)
    return unless org

    sub = org.subscriptions.find_or_initialize_by(stripe_subscription_id: subscription.id)
    sub.update!(
      stripe_customer_id: subscription.customer,
      status: subscription.status,
      current_period_end: Time.at(subscription.current_period_end)
    )
  end

  def handle_subscription_event_hash(subscription)
    customer_id = subscription['customer'] || subscription[:customer]
    org = Organization.find_by(stripe_customer_id: customer_id)
    return unless org

    sub = org.subscriptions.find_or_initialize_by(
      stripe_subscription_id: subscription['id'] || subscription[:id]
    )
    sub.update!(
      stripe_customer_id: customer_id,
      status: subscription['status'] || subscription[:status] || 'incomplete',
      current_period_end: Time.at(subscription['current_period_end'] || subscription[:current_period_end] || Time.now.to_i)
    )
  end

  def handle_subscription_deleted(subscription)
    org = Organization.find_by(stripe_customer_id: subscription.customer)
    return unless org

    sub = org.subscriptions.find_by(stripe_subscription_id: subscription.id)
    sub&.update!(status: 'canceled')
  end

  def handle_subscription_deleted_hash(subscription)
    customer_id = subscription['customer'] || subscription[:customer]
    org = Organization.find_by(stripe_customer_id: customer_id)
    return unless org

    sub = org.subscriptions.find_by(
      stripe_subscription_id: subscription['id'] || subscription[:id]
    )
    sub&.update!(status: 'canceled')
  end

  def handle_invoice_paid(invoice)
    org = Organization.find_by(stripe_customer_id: invoice.customer)
    return unless org

    org.invoices.create!(
      stripe_invoice_id: invoice.id,
      amount_cents: invoice.amount_paid,
      currency: invoice.currency,
      status: invoice.status,
      billing_date: Time.at(invoice.created).to_date
    )
  end

  def handle_invoice_paid_hash(invoice)
    customer_id = invoice['customer'] || invoice[:customer]
    org = Organization.find_by(stripe_customer_id: customer_id)
    return unless org

    org.invoices.create!(
      stripe_invoice_id: invoice['id'] || invoice[:id],
      amount_cents: invoice['amount_paid'] || invoice[:amount_paid] || 0,
      currency: invoice['currency'] || invoice[:currency] || 'usd',
      status: invoice['status'] || invoice[:status] || 'paid',
      billing_date: Time.at(invoice['created'] || invoice[:created] || Time.now.to_i).to_date
    )
  end
end
