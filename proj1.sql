-- COMP9311 15s1 Project 1
--By Jeremy Ortiz (z3461601)
-- MyMyUNSW Solution Template

-- Q1: ...

create or replace view Q1(unswid, name)
as
select p.unswid, p.name
from People p
    join Course_enrolments ce on (ce.student=p.id) 
group by p.unswid, p.name
having count(ce.student) > 65
;



-- Q2: ... 
create or replace view Q2(nstudents, nstaff, nboth)
as
select cast(sum(x.StudentCount) as bigint), cast(sum(x.StaffCount) as bigint), cast(sum(x.BothCount) as bigint)
from (select count(s.id) as StudentCount, 0 as StaffCount, 0 as BothCount
      from Students s where s.id not in (select id from Staff)
union all
      select 0 as StudentCount, count(st.id) as StaffCount, 0 as BothCount
      from Staff st where st.id not in (select id from Students)
union all
      select 0 as StudentCount, 0 as StaffCount, count(s.id) as BothCount
      from Students s
        join Staff st on st.id = s.id
) as x
;

-- Q3: ...
create or replace view CourseConvenor(name, ncourses)
as
select p.name, count(p.name)
from People p
    join Course_staff cs on(cs.staff=p.id)
    join Staff_roles sr on(sr.id=cs.role)
where sr.name = 'Course Convenor' 
group by p.name
--order by count(p.name) DESC
;

create or replace view Q3(name, ncourses)
as
select cc.name, cc.ncourses
from CourseConvenor cc
where cc.ncourses = (select max(ncourses) from CourseConvenor)
;


-- Q4: ..

create or replace view Q4a(id)
as
select p.unswid 
from People p
    join Students s on(s.id = p.id)
    join Program_enrolments pe on(pe.student = s.id)
    join Programs pr on(pr.id = pe.program)
    join Semesters ss on(ss.id = pe.semester)
where ss.term = 'S2' and ss.year = '2005' and pr.code = '3978'
;


create or replace view Q4b(id)
as
select p.unswid
from People p
    join Students s on(s.id = p.id)
    join Program_enrolments pe on(pe.student = s.id)   
    join Stream_enrolments se on(se.partOf = pe.id)
    join Streams st on(st.id = se.stream)
    join Semesters ss on(ss.id = pe.semester)
where ss.term = 'S2' and ss.year = '2005' and st.code = 'SENGA1'
;


create or replace view Q4c(id)
as
select p.unswid
from People p
    join Students s on(s.id = p.id)
    join Program_enrolments pe on(pe.student = s.id)   
    join Programs pr on(pr.id = pe.program)
    join OrgUnits ou on(ou.id = pr.offeredBy)
    join Semesters ss on(ss.id = pe.semester)
where ss.term = 'S2' and ss.year = '2005' and ou.name = 'Computer Science and Engineering, School of'
;


-- Q5: ...
--Gets list of organisations that are committees
create or replace view committeeID(id)
as
select facultyOf(ou.id)
from OrgUnits ou
where ou.utype = 9
;

--Counts the committees and groups them
create or replace view maxCommittee(id,numCount)
as
select cid.id, count(cid.id)
from committeeID cid
where cid.id is not null
group by cid.id
;

create or replace view Q5(name)
as
select ou.name
from Orgunits ou
join (select id from maxCommittee where numcount = (select max(numcount) from maxCommittee)) c on c.id = ou.id
;


-- Q6: ...
create or replace view q6(courseCode, year, term, convenor)
as
select text(s.code), sem.year, text(sem.term), p.name
from People p
    join Course_staff cs on(cs.staff=p.id)
    join Staff_roles sr on(sr.id=cs.role)
    join Courses c on(c.id = cs.course)
    join Subjects s on(s.id = c.subject)
    join Semesters sem on(sem.id = c.semester)
where sr.name = 'Course Convenor' 
;

create or replace function Q6(text)
	returns table (course text, year integer, term text, convenor text)
as $$
select * from q6 where courseCode = $1 --$1 is the course code argument taken
$$ language sql
;
