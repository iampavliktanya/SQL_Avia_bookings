/* 1. � ����� ������� ������ ������ ���������?
 
��������� ������� airports. � ������� ���������� ������� count ������ ���������� ���������� �� airport_code. 
��������� �� city. ��������� ������� � ���������� ������������. */

select city "�����", count(airport_code) "���������� ����������" 
from airports 
group by city
having count(airport_code)>1;

/* 2. � ����� ���������� ���� �����, ����������� ��������� � ������������ ���������� ��������? (���������). 
 
� ���������� t � ������� aircrafts ������ ������������ ��������� �������� �� ���� range.
��� ��� � where ������ ������������ ���������� �������, ������� � ������� ���������. 
�� airport_code � arrival_airport �������� ������� airports � �������� flights.
�� aircraft_code �������� � ����������� t */


select a2.airport_name "��������", t.aircraft_code "��� ��������", t."range" "��������� ��������" 
from airports a2 
join flights f on f.arrival_airport = a2.airport_code 
join (
	select aircraft_code, "range"
	from aircrafts a
	where range = (select max(range) from aircrafts)) t on t.aircraft_code = f.aircraft_code  
group by 1,2,3	

/* 3. ������� 10 ������ � ������������ �������� �������� ������ (�������� LIMIT).

�������� ������ ������ ��� ������� ����� ����������� �������� ������ � ��������������� �� ������� �����. 
��� ��� � ������, ������� ��� �� �������� �������� actual_departure ���, �� ������ �� �� ���������� ��������.
�������� �� ��������. � ������� ��������� LIMIT ������� ������ 10 ������, ���������� � ���������� ���������� */

select flight_id "����", actual_departure - scheduled_departure "����� �������� ������"
from flights f
where actual_departure is not null
order by 2 desc 
limit 10



/* 4. ���� �� �����, �� ������� �� ���� �������� ���������� ������? (������ ��� JOIN) 

��������� ������� bookings. �� book_ref c������� � �������� tickets.
� ������� left join �������� � �������� boarding_passes, ����� ����� ������������� ��������. 
������� �����, ������ �����, �.�. � ����� ����� ����� ���� ��������� ������� */
 
select distinct b.book_ref "�����", bp.boarding_no "�o�������� �����"
from bookings b 
join tickets t on t.book_ref = b.book_ref
left join boarding_passes bp on bp.ticket_no = t.ticket_no
where bp.boarding_no is null 


/* 5. ������� ���������� ��������� ���� ��� ������� �����, �� % ��������� � ������ ���������� ���� � ��������.
�������� ������� � ������������� ������ - ��������� ���������� ���������� ���������� ���������� �� �������
��������� �� ������ ����. �.�. � ���� ������� ������ ���������� ������������� ����� - ������� ������� ��� 
�������� �� ������� ��������� �� ���� ��� ����� ������ ������ � ������� ���. (������� �������, ���������� ���/� cte)


� ������� cte seats ������ ����� ���������� ���� � ������ �������.
� cte coupon ������ ���������� �������� ������� �� ������ ���� � �������� � �������� flights.
�������� ��� cte � ������ ������� ����� ����������� ���� � ��������� ��������, % ��������� � ������ ���������� ����.
� ������� ������� ������� ������ ��������� ���������� ���������� ���������� ����������
�� ������� ��������� �� ������ ����, ������� �������� �� ��������� � �� ���� ����������� � ������� date */

with seats as(
	select a.aircraft_code, count(s.seat_no) 
	from aircrafts a 
	join seats s ON s.aircraft_code = a.aircraft_code 
	group by a.aircraft_code),
coupon as(
	select f.flight_id, count(bp.seat_no), f.aircraft_code, f.departure_airport, f.actual_departure  
	from boarding_passes bp
	join flights f on f.flight_id = bp.flight_id 
	group by f.flight_id)	
select coupon.flight_id "����", coupon.departure_airport "��������",
	coupon.actual_departure "���� ������", 
	seats.count "����� ���-�� ����",
	seats.count - coupon.count "���-�� ��������� ����",
	round(((seats.count - coupon.count)/seats.count::numeric)*100) "% ��������� ����",
	sum(coupon.count) over (partition by coupon.departure_airport, 
	coupon.actual_departure::date order by coupon.actual_departure ) --����� ������������ day trunc, ����� ������ �� �� ���� �����, ��� � �.�.
from coupon
join seats on seats.aircraft_code = coupon.aircraft_code 


/* 6. ������� ���������� ����������� ��������� �� ����� ��������� �� ������ ����������. (��������� ��� ����, �������� ROUND) 

� ������� flights ������ ���������� ��������� �� ������� ��������.
� ���������� �������� ����� ���������� ���������. ������ ���������� ����������� */

select aircraft_code "��� ��������", count(flight_id) "���-�� ���������",
	round((count(flight_id)/
		(select count(flight_id) from flights) ::numeric)*100) "% ��������� �� ���. ���-��"
from flights f 
group by aircraft_code


/* 7. ���� �� ������, � ������� �����  ��������� ������ - ������� �������, ��� ������-������� � ������ ��������? (CTE) 

��� ��� � ����� ����� ��������� ������� � ������ � ������-������, ���� ���������� ����� ������� ������� �� ������� 
� ����� ������� �� ������-������ ������ ������� �����.
���� ������ �� ��� cte business � economy. 
�������� ��� cte �� �������������� ��������
����� �������� ������ ��� ��������� ����������� ��� � �������, ��� ���� �������� � �������� airports.
� ������� ��������, ��� ����������� ��������� �������� � �������-������ ������ ������������ � ������-������. 
����� ������� ��� */


with business as (
	select f.flight_id, tf.fare_conditions, min(tf.amount), f.arrival_airport, f.departure_airport 
	from flights f 
	join ticket_flights tf on tf.flight_id = f.flight_id and fare_conditions ='Business'
	group by 1,2),
economy as(
	select f.flight_id, tf.fare_conditions, max(tf.amount)
	from flights f 
	join ticket_flights tf on tf.flight_id = f.flight_id and fare_conditions ='Economy'
	group by 1,2)
select business.flight_id "�������", a2.city "����� �����������",
	a.city "����� �������",  business.min "MIN ��������� � Business", 
	economy.max " MAX ��������� � Economy"
from business 
join economy on business.flight_id = economy.flight_id
join airports a on a.airport_code = business.arrival_airport 
join airports a2 on a2.airport_code = business.departure_airport 
where business.min < economy.max



/* 8. ����� ������ �������� ��� ������ ������? 
(��������� ������������ � ����������� FROM
�������������� ��������� ������������� (���� �������� �����������, �� ��� �������������)
�������� EXCEPT)

 � ������ ������� ��������� �������� ������������ � ������� ������ ���� ��������� ��� �������.
 �� ������ ������� �������� ������� flights � airports, ����� �������� ����� ��������� �����������
 � �������� �� ������� �����.
 � ������� except �������� �� ������� ������� ������, ������ ��������� �� ������
 ������ �������������.   */

create view fligts_f as 
	select a1.city city1 , a2.city city2
	from airports a1, airports a2  
	where a1.city != a2.city 
	except 
	select a.city, a2.city  
	from flights f 
	join airports a on a.airport_code = f.departure_airport 
	join airports a2 on a2.airport_code = f.arrival_airport 



/* 9. ��������� ���������� ����� �����������, ���������� ������� �������, �������� � ���������� 
������������ ���������� ���������  � ���������, ������������� ��� �����
(�������� RADIANS ��� ������������� sind/cosd
CASE)

��� ����������� ������� ������ cte (��� cte ��������� ������� ���� ������ � ��� ����),
� ������� �������� ������� flights, airports � aircrafts ��� ���� ����� 
�������� ����� ������� ��������� � ������ ����� � ��������� �������� ������� ��������.
����� �� ���������� �� ������� ���������� ����� ����������� �� �������, 
������ ���������� �������, � ������� ��������� ��������� �������� � ���������� ���������� 
  */


with cte as (
	select distinct a.airport_name "�������� �����������" , a2.airport_name "�������� �������", 
	acos(sind(a.latitude) * sind(a2.latitude) + cosd(a.latitude) * cosd(a2.latitude) * 
		cosd(a.longitude - a2.longitude)) *6371 "���������� � ��",
	f.aircraft_code "��� ��������", ac."range" "��������� ������"
from flights f 
join airports a on a.airport_code = f.departure_airport 
join airports a2 on a2.airport_code = f.arrival_airport 
join aircrafts ac on ac.aircraft_code = f.aircraft_code) 
select *,
	case when cte."��������� ������" >= cte."���������� � ��"
		then '�������'
		else '�� �������'
	end	"������������ ��������� ��������"
from cte
order by cte."�������� �����������"


