/* 1. В каких городах больше одного аэропорта?
 
Использую таблицу airports. С помощью агрегатной функции count считаю количество аэропортов по airport_code. 
Группирую по city. Использую условие к результату группировкию. */

select city "Город", count(airport_code) "Количество аэропортов" 
from airports 
group by city
having count(airport_code)>1;

/* 2. В каких аэропортах есть рейсы, выполняемые самолетом с максимальной дальностью перелета? (Подзапрос). 
 
В подзапросе t в таблице aircrafts нахожу максимальную дальность самолета по полю range.
Так как с where нельзя использовать агрегатную функцию, помещаю в условие подзапрос. 
По airport_code и arrival_airport соединяю таблицу airports с таблицей flights.
По aircraft_code соединяю с подзапросом t */


select a2.airport_name "Аэропорт", t.aircraft_code "Код самолета", t."range" "Дальность перелета" 
from airports a2 
join flights f on f.arrival_airport = a2.airport_code 
join (
	select aircraft_code, "range"
	from aircrafts a
	where range = (select max(range) from aircrafts)) t on t.aircraft_code = f.aircraft_code  
group by 1,2,3	

/* 3. Вывести 10 рейсов с максимальным временем задержки вылета (Оператор LIMIT).

Задержку вылета считаю как разницу между фактическим временем вылета и запланированным по каждому рейсу. 
Так как в рейсах, которые еще не вылетели значения actual_departure нет, то убираю их из результата условием.
Сортирую по убыванию. С помощью оператора LIMIT получаю первые 10 рейсов, полученных в результате сортировки */

select flight_id "Рейс", actual_departure - scheduled_departure "Время задержки вылета"
from flights f
where actual_departure is not null
order by 2 desc 
limit 10



/* 4. Были ли брони, по которым не были получены посадочные талоны? (Верный тип JOIN) 

Использую таблицу bookings. По book_ref cоединяю с таблицей tickets.
С помощью left join соединяю с таблицей boarding_passes, чтобы найти отсутствующие значения. 
Выбираю брони, удаляя дубли, т.к. в одной брони может быть несколько билетов */
 
select distinct b.book_ref "Бронь", bp.boarding_no "Пoсадочный талон"
from bookings b 
join tickets t on t.book_ref = b.book_ref
left join boarding_passes bp on bp.ticket_no = t.ticket_no
where bp.boarding_no is null 


/* 5. Найдите количество свободных мест для каждого рейса, их % отношение к общему количеству мест в самолете.
Добавьте столбец с накопительным итогом - суммарное накопление количества вывезенных пассажиров из каждого
аэропорта на каждый день. Т.е. в этом столбце должна отражаться накопительная сумма - сколько человек уже 
вылетело из данного аэропорта на этом или более ранних рейсах в течении дня. (Оконная функция, подзапросы или/и cte)


С помощью cte seats считаю общее количество мест в каждом самолет.
В cte coupon считаю количество выданных талонов на каждый рейс и соединяю с таблицей flights.
Соединяю два cte и нахожу разницу между количеством мест и выданными талонами, % отношение к общему количеству мест.
С помощью оконной функции считаю суммарное накопление количества вывезенных пассажиров
из каждого аэропорта на каждый день, поэтому разделяю по аэропорту и по дате отправления в формате date */

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
select coupon.flight_id "Рейс", coupon.departure_airport "Аэропорт",
	coupon.actual_departure "Дата вылета", 
	seats.count "Общее кол-во мест",
	seats.count - coupon.count "Кол-во свободных мест",
	round(((seats.count - coupon.count)/seats.count::numeric)*100) "% свободных мест",
	sum(coupon.count) over (partition by coupon.departure_airport, 
	coupon.actual_departure::date order by coupon.actual_departure ) --нужно использовать day trunc, когда данные не за один месяц, год и т.п.
from coupon
join seats on seats.aircraft_code = coupon.aircraft_code 


/* 6. Найдите процентное соотношение перелетов по типам самолетов от общего количества. (Подзапрос или окно, оператор ROUND) 

В таблице flights считаю количество перелетов по каждому самолету.
В подзапросе вычисляю общее количество перелетов. Нахожу процентное соотношение */

select aircraft_code "Тип самолета", count(flight_id) "Кол-во перелетов",
	round((count(flight_id)/
		(select count(flight_id) from flights) ::numeric)*100) "% перелетов от общ. кол-ва"
from flights f 
group by aircraft_code


/* 7. Были ли города, в которые можно  добраться бизнес - классом дешевле, чем эконом-классом в рамках перелета? (CTE) 

Так как в одном рейсе множество билетов в бизнес и эконом-классе, буду сравнивать самый дорогой перелет из эконома 
и самый дешевый из бизнес-класса внутри каждого рейса.
Делю логику на два cte business и economy. 
Соединяю два cte по идентификатору перелета
Чтобы получить города как аэропорта отправления так и прилета, два раза соединяю с таблицей airports.
В условии указываю, что минимальная стоимость перелета в бизнесс-классе меньше максимальной в эконом-классе. 
Таких городов нет */


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
select business.flight_id "Перелет", a2.city "Город отправления",
	a.city "Город прилета",  business.min "MIN Стоимость в Business", 
	economy.max " MAX Стоимость в Economy"
from business 
join economy on business.flight_id = economy.flight_id
join airports a on a.airport_code = business.arrival_airport 
join airports a2 on a2.airport_code = business.departure_airport 
where business.min < economy.max



/* 8. Между какими городами нет прямых рейсов? 
(Декартово произведение в предложении FROM
Самостоятельно созданные представления (если облачное подключение, то без представления)
Оператор EXCEPT)

 В первом запросе использую декартво произведения и получаю список всех возможных пар городов.
 Во втором запросе соединяю таблицу flights с airports, чтобы получить город аэропорта отправления
 и прибытия по каждому рейсу.
 С помошью except исключаю из первого запроса данные, которы совпадают со вторым
 Создаю представление.   */

create view fligts_f as 
	select a1.city city1 , a2.city city2
	from airports a1, airports a2  
	where a1.city != a2.city 
	except 
	select a.city, a2.city  
	from flights f 
	join airports a on a.airport_code = f.departure_airport 
	join airports a2 on a2.airport_code = f.arrival_airport 



/* 9. Вычислите расстояние между аэропортами, связанными прямыми рейсами, сравните с допустимой 
максимальной дальностью перелетов  в самолетах, обслуживающих эти рейсы
(Оператор RADIANS или использование sind/cosd
CASE)

Для оптимизации запроса создаю cte (без cte стоимость запроса была больше в два раза),
в котором соединяю таблицы flights, airports и aircrafts для того чтобы 
получить город каждого аэропорта в каждом рейсе и дальность перелета каждого самолета.
Здесь же расчитываю по формуле расстояние между аэропортами по формуле, 
Дальше прописываю условие, в котором сравниваю дальность перелета с полученным растоянием 
  */


with cte as (
	select distinct a.airport_name "Аэропорт отправления" , a2.airport_name "Аэропорт прилета", 
	acos(sind(a.latitude) * sind(a2.latitude) + cosd(a.latitude) * cosd(a2.latitude) * 
		cosd(a.longitude - a2.longitude)) *6371 "Расстояние в км",
	f.aircraft_code "Код самолета", ac."range" "Дальность полета"
from flights f 
join airports a on a.airport_code = f.departure_airport 
join airports a2 on a2.airport_code = f.arrival_airport 
join aircrafts ac on ac.aircraft_code = f.aircraft_code) 
select *,
	case when cte."Дальность полета" >= cte."Расстояние в км"
		then 'Долетит'
		else 'Не долетит'
	end	"Соответствие дальности маршрута"
from cte
order by cte."Аэропорт отправления"


