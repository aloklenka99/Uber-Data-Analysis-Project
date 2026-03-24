/*Objective
The main goals of this SQL project are to:
1. Analyze Uber’s ride data to assess performance in various cities.
2. Study financial data by examining fare trends, cancellations, and payment methods.
3. Evaluate driver performance based on ride counts, ratings, and earnings.
4. Investigate the impact of dynamic pricing and cancellations on revenue.
5. Propose operational improvements using SQL queries and analysis.
6. Implement SQL-based solutions to ensure data integrity and improve query
performance.*/

create database Uber

use  Uber

--create primary key for drivers table
Alter table drivers_data
alter column driver_id nvarchar(255) not null

Alter table drivers_data
add constraint pk_driver_id primary key ( driver_id)

select column_name
from INFORMATION_SCHEMA.COLUMNS
where TABLE_NAME  = 'payments_data'

exec sp_pkeys 'drivers_data'
exec sp_pkeys 'city_data'
exec sp_pkeys'rides_data'
exec sp_pkeys 'payments_data'

--0)City-Level Performance Optimization .
--Which are the top 3 cities where Uber should focus more on driver recruitment based on key metrics such as demand high cancellation rates and driver ratings?
Select top 3 end_city,
COUNT(ride_id) as Num_of_rides,
AVG(rating) as driver_avg_ratings,
cast(count(case 
when ride_status= 'canceled' then 1 end)AS float)/COUNT(ride_id) as cancel_rides
from rides_data
group by end_city
order by 
Num_of_rides desc, 
driver_avg_ratings asc,
cancel_rides desc

--1)Revenue Leakage Analysis
--How can you detect rides with fare discrepancies or those marked as "completed" without any corresponding payment?

select r.ride_id,r.fare as rides_fare,r.ride_status,
p.fare as payment_fare, p.ride_id as payments_ride_id,p.transaction_status
from rides_data r left join payments_data p
on p.ride_id=r.ride_id
where (r.ride_status= 'completed'and p.ride_id is null)
or (r.fare<>p.fare )
or (r.ride_status= 'completed' and p.transaction_status<>'completed')

--2)Cancellation Analysis
--What are the cancellation patterns across cities and ride categories? How do these patterns correlate with revenue from completed rides?

 with ride_summary as(
 select r.start_city,d.vehicle_type,
 COUNT(*) as total_rides,
 COUNT(case when ride_status ='completed' then 1 end) as completed_rides,
 COUNT(case when ride_status ='canceled' then 1 end) as cancel_rides,

 COUNT(case when ride_status ='canceled' then 1 end)*100.0/COUNT(*) as cancel_rates
 from rides_data r left join drivers_data as d
 on d.driver_id= r.driver_id
 group by r.start_city,d.vehicle_type)
 ,
  revenue_summary as(
 select r.start_city,d.vehicle_type,
 SUM(p.fare) as completed_revenue
 from rides_data r join payments_data p
 on p.ride_id=r.ride_id
 join drivers_data d on
 d.driver_id=r.driver_id
 where r.ride_status ='completed'
 and p.transaction_status ='completed'
 group by r.start_city,d.vehicle_type)

 
select rs.start_city,rs.vehicle_type,rs.total_rides,rs.completed_rides,rs.cancel_rides,rs.cancel_rates,
       isnull(re.completed_revenue,0) as completed_revenue
	   from ride_summary as rs left join revenue_summary  as re
	   on 
       rs.start_city = re.start_city
	   and rs.vehicle_type= re.vehicle_type
	   order by rs.cancel_rates desc, re.completed_revenue asc

--3)Cancellation Patterns by Time of Day
--Analyze the cancellation patterns based on different times of day. Which hours have the highest cancellation rates, and what is their impact on revenue?

with hourly_canceleation as(
select 
DATEPART(hour,ri.start_time) as hourly_rides,
COUNT(*) as total_rides,
COUNT(case when ri.ride_status = 'completed' then 1 end) as completed_rides,
COUNT(case when ri.ride_status = 'canceled' then 1 end) as canceled_rides
from rides_data ri
group by DATEPART(hour,ri.start_time)
),
hourly_payment as(
select 
DATEPART(hour,ri.start_time) as hourly_rides,
SUM(pa.fare) as total_fare
from rides_data as ri join payments_data as pa
on ri.ride_id = pa.ride_id
where ri.ride_status = 'completed'
and   pa.transaction_status ='completed'
group by DATEPART(hour,ri.start_time) )

select hc.total_rides,hc.hourly_rides, hc.canceled_rides,
hc.canceled_rides * 100.0/hc.total_rides as cancel_rates,
isnull(hp.total_fare,0) as total_fare
from hourly_canceleation as hc 
left join hourly_payment as hp
on hc.hourly_rides = hp.hourly_rides
order by cancel_rates desc


--4)Seasonal Fare Variations
--How do fare amounts vary across different seasons? Identify any significant trends or anomalies in fare distributions.

select 
case
	when datepart(month,ride_date ) in (11,12,1,2) then 'winter'
	when datepart(month,ride_date ) in (3,4,5,6) then 'summer'
	when datepart(month,ride_date ) in (7,8,9) then 'Rainy'
	when datepart(month,ride_date ) in (10) then 'Post season'
	end as seasons,
round(Avg(fare),2) as avg_fare,
round(max(Fare),2) as max_fare,
round(min(fare),2) as min_fare,
round(stdev(fare),2) as stdv_fare
from  rides_data
group by case
	when datepart(month,ride_date ) in (11,12,1,2) then 'winter'
	when datepart(month,ride_date ) in (3,4,5,6) then 'summer'
	when datepart(month,ride_date ) in (7,8,9) then 'Rainy'
	when datepart(month,ride_date ) in (10) then 'Post season'
	end 
order by avg_fare desc

--5)Average Ride Duration by City
--What is the average ride duration for each city? How does this relate to customer satisfaction? 
select c.city_id,c.city_name,
Avg(datediff(minute,r.start_time,r.end_time)) as avg_ride_duration,
avg(r.rating) as avg_cust_rating
from city_data as c left join drivers_data as d
on c.city_id= d.city_id
left join rides_data as r
on r.driver_id=d.driver_id
where r.ride_status='completed'
and r.rating is not null
group by  c.city_id,c.city_name
order by avg_ride_duration desc

--6)Index for Ride Date Performance Improvement
--How can query performance be improved when filtering rides by date?

create nonclustered index idx_ride_date on rides_data(ride_date)
select ride_id,start_city,end_city,distance_km,Fare
from rides_data
where ride_date ='2024-03-01'
group by ride_id,start_city,end_city,distance_km,Fare

--check indexes
select name, type_desc
from sys.indexes
where object_id=object_id('rides_data')

--7)View for Average Fare by City
--How can you quickly access information on average fares for each city?

create view avg_fare_of_cities as
select city_id,city_name,     
round(AVG(avg_fare),2) as Avg_fare_by_cities
from city_data
group by city_id,city_name
go

select*from avg_fare_of_cities

--9)View for Driver Performance Metrics
--What performance metrics can be summarized to assess driver efficiency?
create view driver_efficiency as
select driver_id,driver_name,
round(ride_acceptance_rate,
round(avg_driver_rating,2) )as avg_rating_of_driver,
total_rides,round(total_earnings,2) as total_earnings,      
round(case when total_rides = 0 then 0
else total_earnings*1.0/total_rides
end,2) as earing_per_ride,
years_of_experience
from drivers_data
go
select *from driver_efficiency

--10)Index on Payment Method for Faster Querying
--How can you optimize query performance for payment realted queries?
 
create nonclustered index payment_realted_data on payments_data(transaction_status )
 select payment_id,ride_id,fare,payment_method,driver_earnings,
 payment_method,transaction_status from  payments_data 
 where transaction_status ='completed'

 select name,type_desc
 from sys.indexes
 where object_id=object_id('payments_data')

select*from city_data
select*from drivers_data
select * from rides_data
select * from payments_data





