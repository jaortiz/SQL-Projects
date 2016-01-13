-- COMP9311 15s1 Proj 2


-- Q1: ...

create or replace function Q1(integer) returns text
as
$$
select p.name
from People p 
where p.id = $1 or p.unswid =$1
$$ language sql
;

-- Q2: ...

create or replace function Q2(sid integer)
	returns setof NewTranscriptRecord
as $$
declare 
	rec NewTranscriptRecord;
	UOCtotal integer := 0;
	UOCpassed integer := 0;
	wsum integer := 0;
	wam integer := 0;
	x integer;
begin
	select s.id into x
	from   Students s join People p on (s.id = p.id)
	where  p.unswid = sid;
	if (not found) then
		raise EXCEPTION 'Invalid student %',sid;
	end if;
	for rec in
		select su.code,   
		         substr(t.year::text,3,2)||lower(t.term),
		         pr.code,   --ADDED
		         substr(su.name,1,20),
		         e.mark, e.grade, su.uoc
		from   People p
		         join Students s on (p.id = s.id)
		         join Course_enrolments e on (e.student = s.id)
		         join Program_enrolments pe on (pe.student = s.id)  --ADDED
		         join Programs pr on (pr.id = pe.program)       --ADDED
		         join Courses c on (c.id = e.course)
		         join Subjects su on (c.subject = su.id)
		         join Semesters t on (c.semester = t.id)
		where  p.unswid = sid
		group by su.code,t.year,t.term, pr.code, su.name, e.mark, e.grade, su.uoc, t.starting
		order  by t.starting, su.code
	loop
		if (rec.grade = 'SY') then
			UOCpassed := UOCpassed + rec.uoc;
		elsif (rec.mark is not null) then
			if (rec.grade in ('PT','PC','PS','CR','DN','HD','A','B','C')) then
				-- only counts towards creditted UOC
				-- if they passed the course
				UOCpassed := UOCpassed + rec.uoc;
			end if;
			-- we count fails towards the WAM calculation
			UOCtotal := UOCtotal + rec.uoc;
			-- weighted sum based on mark and uoc for course
			wsum := wsum + (rec.mark * rec.uoc);
			-- don't give UOC if they failed
			if (rec.grade not in ('PT','PC','PS','CR','DN','HD','A','B','C')) then
				rec.uoc := 0;
			end if;

		end if;
		return next rec;
	end loop;
	if (UOCtotal = 0) then
		rec := (null,null,null,'No WAM available',null,null,null);
	else
		wam := wsum / UOCtotal;
		rec := (null,null,null,'Overall WAM',wam,null,UOCpassed);
	end if;
	-- append the last record containing the WAM
	return next rec;
end;
$$ language plpgsql
;


-- Q3: ...

create or replace function Q3(gID integer)
	returns setof AcObjRecord
as $$
declare
   -- ... PLpgSQL variable delcarations ...
    tempRec AcObjRecord;      --These are record types not tables, a set of records is a table
                              --Hold the info i.e. gtype and definition (pattern)
    rec AcObjRecord;
    
    patternArr text[];     --Array to store the patterns after splitting
    pattern text;   --Variable to hold a pattern in for each
    strTemp text;
    strTemp2 text;
    bracketVal text;
    
    --used for looping through []
    pos integer;
    num text;       
    startNum integer;
    endNum integer;

begin   
    --Getting the Acad_object_groups record as specified by the group id and by
    --definiton type 'pattern'
    
    select aog.gtype, aog.definition into tempRec
    from Acad_object_groups aog
    where aog.id = gID and aog.gdefBy = 'pattern';
    
    if (tempRec.objtype is null or tempRec.object is null) then     -- check if not empty
     return next tempRec;
      
    else
        --Split into array by delimeter ','
        select regexp_split_to_array(tempRec.object,',') into patternArr;
        
        --loop through array of patterns
        foreach pattern in array patternArr
        loop
            if((pattern like '%GEN%') or (pattern like '%FREE%')) then --just return the pattern
                rec.objtype := tempRec.objtype;
                rec.object := pattern;  
                return next rec;
                
            elseif(pattern like '%{%') then -- i.e. {COMP1917,COMP3311} ignore i.e. return empty result
                rec.objtype := null;
                rec.object := null;
                return next rec;
                
            elseif(pattern like '%/F=%') then --i.e.all/F=ARTSC ignore i.e return empty result
                rec.objtype := null;
                rec.object := null;
                return next rec;
                
            elsif(pattern like '%x%') then
                rec.objtype := null;
                rec.object := null;
                return next rec;
                
            elsif(pattern like '%[%') then     --i.e. COMP[34]###, COMP[1-4]### etc 
               --Replace '[' and ']' for splitting string 
                strTemp = replace(pattern,'[',',');
                strTemp = replace(strTemp,']',',');
                strTemp = replace(strTemp,'#','%');
 
               select split_part(strTemp,',',2) into bracketVal;    
               
                if(bracketVal like '%-%') then  --for [x-x] cases
                    startNum := substr(bracketVal,1,1)::integer;
                    endNum := substr(bracketVal,3,1)::integer;
                    
                    for pos in startNum..endNum loop
                        strTemp2 := replace(strTemp,','||bracketVal||',',pos::text);
                        for rec.object in 
                            select distinct s.code
                            from Subjects s
                            where s.code like strTemp2
                            order by s.code
                        loop
                            rec.objtype := tempRec.objtype;
                            return next rec;
                        end loop;
                    end loop;
                    
                else --for [xxx] cases
                    for pos in 1..length(bracketVal) loop
                        select substr(bracketVal,pos,1) into num;
                        strTemp2 := replace(strTemp,','||bracketVal||',',num);
                        for rec.object in 
                            select distinct s.code
                            from Subjects s
                            where s.code like strTemp2
                            order by s.code
                        loop
                            rec.objtype := tempRec.objtype;
                            return next rec;
                        end loop;
                        
                    end loop;
                end if;

            elseif(pattern like '%(%') then --for (COMP|SENG|BINF)1### cases etc.
                strTemp := replace(pattern,'#','.');
                for rec.object in 
                    select distinct s.code
                    from Subjects s
                    where s.code ~ strTemp  --use regexp in order to take advantage of pipe literal
                    order by s.code
                loop
                    rec.objtype := tempRec.objtype;
                    return next rec;
                end loop;
            
            else  --Normal Cases i.e. COMP1###, COMP19## etc.    
                strTemp =  replace(pattern, '#','_');
                --strTemp = replace(strTemp,'x','_');     --for the ARTSxxxx cases
                for rec.object in 
                    select distinct s.code
                    from Subjects s
                    where s.code like strTemp
                    order by s.code
                loop
                    rec.objtype := tempRec.objtype;
                    return next rec;
                end loop;
            end if;
        end loop;
    end if;
end;
$$ language plpgsql
;



























