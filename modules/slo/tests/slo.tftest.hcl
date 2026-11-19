mock_provider "aws" {}

variables {
  name                    = "test"
  alb_arn_suffix          = "app/test/0123456789abcdef"
  target_group_arn_suffix = "targetgroup/app/0123456789abcdef"
}

run "four_burn_windows_and_two_pages" {
  command = plan

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.burn) == 4
    error_message = "Expect a long and a short window for both the fast and the slow burn rule."
  }

  assert {
    condition     = aws_cloudwatch_composite_alarm.page_fast.alarm_name == "test-slo-page-fast" && aws_cloudwatch_composite_alarm.page_slow.alarm_name == "test-slo-page-slow"
    error_message = "Both pages must exist."
  }
}

run "fast_burn_threshold_is_14_4_times_the_budget" {
  command = plan

  # 99.9% objective -> budget 0.001 -> 14.4 x 0.001 = 0.0144
  assert {
    condition     = abs(aws_cloudwatch_metric_alarm.burn["fast-long"].threshold - 0.0144) < 0.0000001
    error_message = "Fast burn threshold should be 14.4 x the error budget."
  }

  assert {
    condition     = abs(aws_cloudwatch_metric_alarm.burn["slow-long"].threshold - 0.006) < 0.0000001
    error_message = "Slow burn threshold should be 6 x the error budget."
  }
}

run "stricter_objective_lowers_the_thresholds" {
  command = plan

  variables {
    slo_target = 0.9999
  }

  assert {
    condition     = abs(aws_cloudwatch_metric_alarm.burn["fast-long"].threshold - 0.00144) < 0.0000001
    error_message = "A 99.99% objective has a ten times smaller budget."
  }
}

run "short_windows_are_shorter_than_long_windows" {
  command = plan

  assert {
    condition = (
      [for q in aws_cloudwatch_metric_alarm.burn["fast-short"].metric_query : one(q.metric).period if q.id == "requests"][0]
      < [for q in aws_cloudwatch_metric_alarm.burn["fast-long"].metric_query : one(q.metric).period if q.id == "requests"][0]
    )
    error_message = "The short window must be shorter than the long window."
  }
}

run "no_traffic_is_not_an_outage" {
  command = plan

  assert {
    condition     = alltrue([for a in aws_cloudwatch_metric_alarm.burn : a.treat_missing_data == "notBreaching"])
    error_message = "Missing data must not fire a burn alert."
  }
}

run "email_subscription_only_when_given" {
  command = plan

  assert {
    condition     = length(aws_sns_topic_subscription.email) == 0
    error_message = "No email means no subscription."
  }
}

run "rejects_an_objective_of_100_percent" {
  command = plan

  variables {
    slo_target = 1
  }

  expect_failures = [var.slo_target]
}
