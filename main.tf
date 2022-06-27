
data "aws_availability_zones" "azs" {
  state = "available" #it will look at the avail azs#
}

#define AMI 
data "aws_ami" "ami" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.10-hvm-*-gp2"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_key_pair" "koji-key" {
  key_name = "kojitech_keypair"
}

#define autoscaling launch configuration
resource "aws_launch_configuration" "custom-launch-config" {
  name          = "custom-launch-config"
  image_id      = data.aws_ami.ami.id
  instance_type = "t2.micro"
  key_name      = data.aws_key_pair.koji-key.key_name
}

#define autoscaling group
resource "aws_autoscaling_group" "custom-group-autoscaling" {
  name                      = "custom-group-autoscaling"
  max_size                  = 3
  min_size                  = 1
  health_check_grace_period = 60
  health_check_type         = "EC2"
  force_delete         = true
  launch_configuration = aws_launch_configuration.custom-launch-config.name
  vpc_zone_identifier  = ["subnet-02a7ae88655bda51d"]

  tag {
    key                 = "Name"
    value               = "custom-ec2-instance"
    propagate_at_launch = true
  }
}

#define autoscaling policy
resource "aws_autoscaling_policy" "custom-autoscaling-policy" {
  name                   = "custom-autoscaling-policy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.custom-group-autoscaling.name
  policy_type            = "SimpleScaling"
}

#define cloud watch monitoring
resource "aws_cloudwatch_metric_alarm" "custom-cpu-alarm" {
  alarm_name          = "custom-cpu-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "2"

  dimensions = {
    "AutoScalingGroupName" = aws_autoscaling_group.custom-group-autoscaling.name
  }
  actions_enabled   = true
  alarm_description = "This metric monitors ec2 cpu utilization"
  alarm_actions     = [aws_autoscaling_policy.custom-autoscaling-policy.arn]
}

#define auto descaling policy
resource "aws_autoscaling_policy" "custom-policy-scaledown" {
  name                   = "custom-policy-scaledown"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.custom-group-autoscaling.name
  policy_type            = "SimpleScaling"
}

#define descaling cloud watch
resource "aws_cloudwatch_metric_alarm" "custom-cpu-scaledown" {
  alarm_name          = "custom-cpu-scaledown"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "2"

  dimensions = {
    "AutoScalingGroupName" = aws_autoscaling_group.custom-group-autoscaling.name
  }
  actions_enabled   = true
  alarm_description = "This metric monitors ec2 cpu utilization decrease"
  alarm_actions     = [aws_autoscaling_policy.custom-policy-scaledown.arn]
}