module ApplicationHelper
  def badge_class_for_status(status)
    case status
    when 'overloaded' then 'tf-badge--priority-high'
    when 'high' then 'tf-badge--warning'
    when 'optimal' then 'tf-badge--success'
    when 'underutilized' then 'tf-badge--muted'
    else 'tf-badge--muted'
    end
  end

  def color_for_utilization(percent)
    case percent
    when 0..50 then 'var(--tf-color-success)'
    when 50..85 then 'var(--tf-color-primary)'
    when 85..100 then 'var(--tf-color-warning)'
    else 'var(--tf-color-danger)'
    end
  end

  def utilization_status(utilization)
    case utilization
    when 0..50 then 'underutilized'
    when 50..85 then 'optimal'
    when 85..100 then 'high'
    else 'overloaded'
    end
  end
end
