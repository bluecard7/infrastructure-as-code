# autoscaling

Demonstrates an auto-scaling group that serves simple html through an application load balancer.
The instances in the group are created through a launch template.

Starting off with 2 instances, a CloudWatch alarm will be set off after 2 minutes of under-utilizing the CPU (< 50%>). 
This will trigger an auto-scaling policy that will remove 1 instance from the auto-scaling group. 
This repeats every 2 minutes, but a minimum of 1 instance will be kept in the group.
