--
-- PostgreSQL database dump
--

\restrict noCiqgKGtxETYcYbvpl0hsez5qKB2vcRHeF5OVgjzybmWRb5lsrMyxLVqaCqiqK

-- Dumped from database version 16.13 (Homebrew)
-- Dumped by pg_dump version 16.13 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: batch_course_map; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.batch_course_map (
    batch_id integer NOT NULL,
    course_id integer NOT NULL
);


--
-- Name: TABLE batch_course_map; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.batch_course_map IS 'Junction table: links student batches to their required courses';


--
-- Name: constraint_violation_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.constraint_violation_log (
    violation_id integer NOT NULL,
    timetable_id integer,
    constraint_id integer,
    severity character varying(20) DEFAULT 'WARNING'::character varying NOT NULL,
    violation_detail text NOT NULL,
    detected_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_severity CHECK (((severity)::text = ANY ((ARRAY['INFO'::character varying, 'WARNING'::character varying, 'ERROR'::character varying, 'CRITICAL'::character varying])::text[])))
);


--
-- Name: TABLE constraint_violation_log; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.constraint_violation_log IS 'Audit log: records every constraint violation with timestamp and details';


--
-- Name: constraint_violation_log_violation_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.constraint_violation_log_violation_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: constraint_violation_log_violation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.constraint_violation_log_violation_id_seq OWNED BY public.constraint_violation_log.violation_id;


--
-- Name: course; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.course (
    course_id integer NOT NULL,
    course_code character varying(20) NOT NULL,
    course_name character varying(150) NOT NULL,
    lecture_hrs integer DEFAULT 0,
    tutorial_hrs integer DEFAULT 0,
    practical_hrs integer DEFAULT 0,
    credits integer DEFAULT 0,
    ltpc character varying(15),
    course_type character varying(80) DEFAULT 'Core'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: TABLE course; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.course IS 'Academic course catalogue with L-T-P-C credit structure';


--
-- Name: COLUMN course.ltpc; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.course.ltpc IS 'Lecture-Tutorial-Practical-Credits string (e.g., 3-0-0-3)';


--
-- Name: COLUMN course.course_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.course.course_type IS 'Course classification — Core, Technical Elective, HASS Elective, Open Elective, Specialization, etc.';


--
-- Name: course_course_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.course_course_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: course_course_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.course_course_id_seq OWNED BY public.course.course_id;


--
-- Name: faculty; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.faculty (
    faculty_id integer NOT NULL,
    name character varying(100),
    short_name character varying(20) NOT NULL,
    department character varying(100),
    email character varying(150),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: TABLE faculty; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.faculty IS 'Teaching staff records with unique short names for timetable display';


--
-- Name: COLUMN faculty.short_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.faculty.short_name IS 'Unique code used in timetable (e.g., PMJ, ST, HSJ)';


--
-- Name: faculty_course_map; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.faculty_course_map (
    assignment_id integer NOT NULL,
    faculty_id integer NOT NULL,
    course_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: TABLE faculty_course_map; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.faculty_course_map IS 'Junction table: authorizes faculty-course pairings. assignment_id is used by Master_Timetable';


--
-- Name: COLUMN faculty_course_map.assignment_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.faculty_course_map.assignment_id IS 'Surrogate key — Master_Timetable references this, NOT faculty_id or course_id directly';


--
-- Name: faculty_course_map_assignment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.faculty_course_map_assignment_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: faculty_course_map_assignment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.faculty_course_map_assignment_id_seq OWNED BY public.faculty_course_map.assignment_id;


--
-- Name: faculty_faculty_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.faculty_faculty_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: faculty_faculty_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.faculty_faculty_id_seq OWNED BY public.faculty.faculty_id;


--
-- Name: master_timetable; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.master_timetable (
    timetable_id integer NOT NULL,
    assignment_id integer NOT NULL,
    batch_id integer NOT NULL,
    room_id integer,
    slot_id integer NOT NULL,
    is_moved boolean DEFAULT false,
    original_slot_group character varying(15),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: TABLE master_timetable; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.master_timetable IS 'Central fact table: final generated schedule using FK-only references';


--
-- Name: COLUMN master_timetable.assignment_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.master_timetable.assignment_id IS 'Links to faculty_course_map — inherits pre-approved faculty-course pairing';


--
-- Name: COLUMN master_timetable.is_moved; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.master_timetable.is_moved IS 'TRUE if the CSP solver moved this course from its original slot';


--
-- Name: COLUMN master_timetable.original_slot_group; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.master_timetable.original_slot_group IS 'The slot group from the input Excel (before solver reassignment)';


--
-- Name: master_timetable_timetable_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.master_timetable_timetable_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: master_timetable_timetable_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.master_timetable_timetable_id_seq OWNED BY public.master_timetable.timetable_id;


--
-- Name: room; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.room (
    room_id integer NOT NULL,
    room_number character varying(30) NOT NULL,
    room_type character varying(50) DEFAULT 'Lecture Hall'::character varying,
    capacity integer DEFAULT 0,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_capacity CHECK ((capacity >= 0))
);


--
-- Name: TABLE room; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.room IS 'Physical classrooms and labs with seating capacity';


--
-- Name: room_room_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.room_room_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: room_room_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.room_room_id_seq OWNED BY public.room.room_id;


--
-- Name: scheduling_constraint; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.scheduling_constraint (
    constraint_id integer NOT NULL,
    constraint_name character varying(100) NOT NULL,
    constraint_type character varying(10) NOT NULL,
    scope character varying(20) NOT NULL,
    rule_description text NOT NULL,
    enforcement_level character varying(20) DEFAULT 'APPLICATION'::character varying NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    parameters_json jsonb DEFAULT '{}'::jsonb,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_constraint_type CHECK (((constraint_type)::text = ANY ((ARRAY['HARD'::character varying, 'SOFT'::character varying])::text[]))),
    CONSTRAINT chk_enforcement CHECK (((enforcement_level)::text = ANY ((ARRAY['DATABASE'::character varying, 'APPLICATION'::character varying, 'BOTH'::character varying])::text[]))),
    CONSTRAINT chk_scope CHECK (((scope)::text = ANY ((ARRAY['FACULTY'::character varying, 'ROOM'::character varying, 'BATCH'::character varying, 'COURSE'::character varying, 'GLOBAL'::character varying])::text[])))
);


--
-- Name: TABLE scheduling_constraint; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.scheduling_constraint IS 'Scheduling rules stored as data — queryable, toggleable, auditable';


--
-- Name: COLUMN scheduling_constraint.constraint_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.scheduling_constraint.constraint_type IS 'HARD = must be satisfied; SOFT = optimization goal';


--
-- Name: COLUMN scheduling_constraint.enforcement_level; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.scheduling_constraint.enforcement_level IS 'DATABASE = enforced via UNIQUE/CHECK; APPLICATION = enforced in Python CSP solver';


--
-- Name: COLUMN scheduling_constraint.parameters_json; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.scheduling_constraint.parameters_json IS 'Rule-specific parameters as JSON (e.g., {"max_consecutive": 2})';


--
-- Name: scheduling_constraint_constraint_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.scheduling_constraint_constraint_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: scheduling_constraint_constraint_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.scheduling_constraint_constraint_id_seq OWNED BY public.scheduling_constraint.constraint_id;


--
-- Name: student_batch; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.student_batch (
    batch_id integer NOT NULL,
    program_name character varying(50),
    sub_batch character varying(80) NOT NULL,
    section character varying(20) DEFAULT 'All'::character varying NOT NULL,
    year integer,
    headcount integer DEFAULT 0,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_headcount CHECK ((headcount >= 0))
);


--
-- Name: TABLE student_batch; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.student_batch IS 'Student cohorts defined by program, sub-batch, and section';


--
-- Name: COLUMN student_batch.sub_batch; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.student_batch.sub_batch IS 'E.g., ICT + CS, CS-Only, MnC';


--
-- Name: COLUMN student_batch.section; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.student_batch.section IS 'E.g., Sec A, Sec B, or All';


--
-- Name: student_batch_batch_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.student_batch_batch_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: student_batch_batch_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.student_batch_batch_id_seq OWNED BY public.student_batch.batch_id;


--
-- Name: time_slot; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.time_slot (
    slot_id integer NOT NULL,
    day_of_week character varying(15) NOT NULL,
    start_time time without time zone NOT NULL,
    end_time time without time zone NOT NULL,
    slot_group character varying(15) NOT NULL,
    CONSTRAINT chk_day CHECK (((day_of_week)::text = ANY ((ARRAY['Monday'::character varying, 'Tuesday'::character varying, 'Wednesday'::character varying, 'Thursday'::character varying, 'Friday'::character varying])::text[]))),
    CONSTRAINT chk_time_order CHECK ((end_time > start_time))
);


--
-- Name: TABLE time_slot; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.time_slot IS 'University scheduling grid: 5 days × 5 periods mapped to 8 slot groups';


--
-- Name: COLUMN time_slot.slot_group; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.time_slot.slot_group IS 'Slot grouping (Slot-1 through Slot-8, or Slot-Free)';


--
-- Name: time_slot_slot_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.time_slot_slot_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: time_slot_slot_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.time_slot_slot_id_seq OWNED BY public.time_slot.slot_id;


--
-- Name: v_faculty_schedule; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_faculty_schedule AS
 SELECT f.short_name AS faculty,
    f.name AS full_name,
    ts.day_of_week,
    ts.start_time,
    ts.end_time,
    c.course_code,
    c.course_name,
    sb.sub_batch,
    sb.section,
    r.room_number
   FROM ((((((public.master_timetable mt
     JOIN public.faculty_course_map fcm ON ((mt.assignment_id = fcm.assignment_id)))
     JOIN public.faculty f ON ((fcm.faculty_id = f.faculty_id)))
     JOIN public.course c ON ((fcm.course_id = c.course_id)))
     JOIN public.student_batch sb ON ((mt.batch_id = sb.batch_id)))
     JOIN public.time_slot ts ON ((mt.slot_id = ts.slot_id)))
     LEFT JOIN public.room r ON ((mt.room_id = r.room_id)))
  ORDER BY f.short_name, ts.day_of_week, ts.start_time;


--
-- Name: VIEW v_faculty_schedule; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_faculty_schedule IS 'Per-faculty schedule view sorted by day and time';


--
-- Name: v_master_timetable; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_master_timetable AS
 SELECT mt.timetable_id,
    ts.day_of_week,
    ts.start_time,
    ts.end_time,
    ts.slot_group,
    c.course_code,
    c.course_name,
    c.course_type,
    c.ltpc,
    f.short_name AS faculty_short_name,
    f.name AS faculty_full_name,
    sb.sub_batch,
    sb.section,
    sb.program_name,
    r.room_number,
    r.capacity AS room_capacity,
    mt.is_moved,
    mt.original_slot_group
   FROM ((((((public.master_timetable mt
     JOIN public.faculty_course_map fcm ON ((mt.assignment_id = fcm.assignment_id)))
     JOIN public.faculty f ON ((fcm.faculty_id = f.faculty_id)))
     JOIN public.course c ON ((fcm.course_id = c.course_id)))
     JOIN public.student_batch sb ON ((mt.batch_id = sb.batch_id)))
     JOIN public.time_slot ts ON ((mt.slot_id = ts.slot_id)))
     LEFT JOIN public.room r ON ((mt.room_id = r.room_id)));


--
-- Name: VIEW v_master_timetable; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_master_timetable IS 'Human-readable timetable with all entity details joined';


--
-- Name: v_room_utilization; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_room_utilization AS
 SELECT r.room_number,
    r.room_type,
    r.capacity,
    count(mt.timetable_id) AS total_classes,
    round((((count(mt.timetable_id))::numeric * 100.0) / (25)::numeric), 1) AS utilization_pct
   FROM (public.room r
     LEFT JOIN public.master_timetable mt ON ((r.room_id = mt.room_id)))
  GROUP BY r.room_id, r.room_number, r.room_type, r.capacity
  ORDER BY (round((((count(mt.timetable_id))::numeric * 100.0) / (25)::numeric), 1)) DESC;


--
-- Name: VIEW v_room_utilization; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_room_utilization IS 'Room utilization statistics — classes per room out of 25 possible slots';


--
-- Name: constraint_violation_log violation_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.constraint_violation_log ALTER COLUMN violation_id SET DEFAULT nextval('public.constraint_violation_log_violation_id_seq'::regclass);


--
-- Name: course course_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.course ALTER COLUMN course_id SET DEFAULT nextval('public.course_course_id_seq'::regclass);


--
-- Name: faculty faculty_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.faculty ALTER COLUMN faculty_id SET DEFAULT nextval('public.faculty_faculty_id_seq'::regclass);


--
-- Name: faculty_course_map assignment_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.faculty_course_map ALTER COLUMN assignment_id SET DEFAULT nextval('public.faculty_course_map_assignment_id_seq'::regclass);


--
-- Name: master_timetable timetable_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.master_timetable ALTER COLUMN timetable_id SET DEFAULT nextval('public.master_timetable_timetable_id_seq'::regclass);


--
-- Name: room room_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.room ALTER COLUMN room_id SET DEFAULT nextval('public.room_room_id_seq'::regclass);


--
-- Name: scheduling_constraint constraint_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scheduling_constraint ALTER COLUMN constraint_id SET DEFAULT nextval('public.scheduling_constraint_constraint_id_seq'::regclass);


--
-- Name: student_batch batch_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_batch ALTER COLUMN batch_id SET DEFAULT nextval('public.student_batch_batch_id_seq'::regclass);


--
-- Name: time_slot slot_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.time_slot ALTER COLUMN slot_id SET DEFAULT nextval('public.time_slot_slot_id_seq'::regclass);


--
-- Data for Name: batch_course_map; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.batch_course_map (batch_id, course_id) FROM stdin;
10	50
10	79
10	78
10	70
10	33
10	63
10	38
10	56
10	32
11	54
11	72
11	20
11	66
12	73
13	43
13	68
14	62
14	47
15	59
16	71
1	8
1	1
1	2
1	3
1	4
1	6
2	7
2	1
2	2
2	3
2	4
2	5
2	6
3	1
3	2
3	3
3	4
3	5
3	6
4	1
4	10
4	11
4	12
4	9
5	21
6	22
6	25
6	23
6	13
6	24
7	15
7	13
7	17
7	18
7	14
7	16
8	15
8	13
8	17
8	20
8	19
8	14
8	16
9	30
9	27
9	31
9	29
9	28
9	26
17	76
17	74
17	75
18	35
18	24
18	33
18	37
18	38
18	36
18	32
18	34
19	40
19	19
19	41
19	42
19	39
19	32
20	45
20	43
20	20
20	46
20	44
21	50
21	49
21	47
21	53
21	52
21	51
21	48
22	54
22	57
22	58
22	56
22	55
23	62
23	59
23	63
23	61
23	60
24	65
24	64
25	68
25	67
25	66
26	69
27	70
28	72
28	71
29	73
30	33
30	38
30	41
30	58
30	77
30	39
31	69
31	42
31	44
32	50
32	43
32	19
32	61
32	46
33	67
33	66
34	75
34	47
34	52
34	51
34	48
35	62
35	54
35	60
36	59
37	72
38	70
38	71
39	68
40	73
41	35
41	24
41	33
41	37
41	38
41	36
41	34
42	40
42	59
42	65
42	41
42	42
42	39
43	45
43	43
43	20
43	69
43	46
43	44
44	50
44	49
44	47
44	53
44	52
44	51
44	48
45	54
45	57
45	58
45	56
45	55
46	62
46	63
46	61
46	60
47	64
48	72
48	71
48	19
48	67
48	66
49	73
50	68
51	70
52	33
52	38
52	41
52	58
52	39
53	75
53	59
53	36
53	42
53	44
54	50
54	43
54	19
54	61
54	46
55	67
55	66
56	47
56	52
56	51
56	48
57	62
57	54
57	69
57	60
58	68
59	72
60	73
61	70
61	71
62	88
62	90
62	89
62	91
62	61
62	46
63	57
63	51
64	67
65	56
66	83
66	86
66	84
66	87
66	85
67	36
67	46
67	81
68	50
68	52
68	61
69	64
70	57
70	56
71	41
71	58
71	80
72	42
73	57
73	64
74	49
74	40
74	82
74	37
75	45
\.


--
-- Data for Name: constraint_violation_log; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.constraint_violation_log (violation_id, timetable_id, constraint_id, severity, violation_detail, detected_at) FROM stdin;
\.


--
-- Data for Name: course; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.course (course_id, course_code, course_name, lecture_hrs, tutorial_hrs, practical_hrs, credits, ltpc, course_type, created_at) FROM stdin;
1	HM106	Approaches to Indian Society	3	0	0	3	3-0-0-3	Core	2026-04-22 16:51:13.264274
2	IC121	Digital Logic and Computer Organization	3	0	2	4	3-0-2-4	Core	2026-04-22 16:51:13.264274
3	IT205	Data Structures	3	0	0	3	3-0-0-3	Core	2026-04-22 16:51:13.264274
4	IT206	Data Structure Lab using OOP	1	0	2	2	1-0-2-2	Core	2026-04-22 16:51:13.264274
5	SC205	Discrete Mathematics	3	1	0	4	3-1-0-4	Core	2026-04-22 16:51:13.264274
6	SC217	Electromagnetic Theory	3	1	0	4	3-1-0-4	Core	2026-04-22 16:51:13.264274
7	HM001	North Indian Classical Music 1	0	0	2	1	0-0-2-1	Open	2026-04-22 16:51:13.264274
8	ED121	Engineering Mahematics II	3	1	0	4	3-1-0-4	Core	2026-04-22 16:51:13.264274
9	MC215	Linear Algebra	3	1	0	4	3-1-0-4	Core	2026-04-22 16:51:13.264274
10	MC122	Object Oriented Programming	2	0	2	3	2-0-2-3	Core	2026-04-22 16:51:13.264274
11	MC124	Data Structures and Algorithms	3	0	2	4	3-0-2-4	Core	2026-04-22 16:51:13.264274
12	MC125	Functions of Single Variable and ODEs	3	1	0	4	3-1-0-4	Core	2026-04-22 16:51:13.264274
13	EL203	Embedded Hardware Design	3	0	2	4	3-0-2-4	Core	2026-04-22 16:51:13.264274
14	IT214	Database Management System	3	0	2	4	3-0-2-4	Core	2026-04-22 16:51:13.264274
15	CT216	Introduction to Communication Systems	3	0	2	4	3-0-2-4	Core	2026-04-22 16:51:13.264274
16	SC224	Probability and Statistics	3	1	0	4	3-1-0-4	Core	2026-04-22 16:51:13.264274
17	HM116	Principles of Economics	3	0	0	3	3-0-0-3	Core	2026-04-22 16:51:13.264274
18	IE410	Introduction to Robotics (ICT only)	3	0	2	4	3-0-2-4	ICT & Technical Elective (RAS Core1)	2026-04-22 16:51:13.264274
19	IE422	Soft Computing (ICT only)	3	0	2	4	3-0-2-4	ICT & Technical Elective	2026-04-22 16:51:13.264274
20	IE402	Optimization (ICT only)	3	0	2	4	3-0-2-4	ICT & Technical Elective (Honours Cat)	2026-04-22 16:51:13.264274
21	CS201	Introductory Computational Physics	3	0	3	4	3-0-3-4.5	Core	2026-04-22 16:51:13.264274
22	ED221	Digital IC Design and Tape out	3	0	0	3	3-0-0-3	Core	2026-04-22 16:51:13.264274
23	ED224	Analog Electronics	3	0	2	4	3-0-2-4	Core	2026-04-22 16:51:13.264274
24	EL469	VLSI Technology	3	0	0	3	3-0-0-3	Specialization Elective-1	2026-04-22 16:51:13.264274
25	ED223	Entrepreneurship and Product Design	1	0	4	3	1-0-4-3	Core	2026-04-22 16:51:13.264274
26	MC226	Environmental Studies	2	0	0	2	2-0-0-2	Core	2026-04-22 16:51:13.264274
27	MC222	Real and Complex Analysis	3	1	0	4	3-1-0-4	Core	2026-04-22 16:51:13.264274
28	MC225	Numerical and Computational Methods	3	0	2	4	3-0-2-4	Core	2026-04-22 16:51:13.264274
29	MC224	Parallel and Distributed Algorithms	3	1	0	4	3-1-0-4	Core	2026-04-22 16:51:13.264274
30	MC221	Mathematical Statistics	3	1	0	4	3-1-0-4	Core	2026-04-22 16:51:13.264274
31	MC223	Theory of Computation	3	1	0	4	3-1-0-4	Core	2026-04-22 16:51:13.264274
32	SC407	Environmental Science	3	0	0	3	3-0-0-3	Core	2026-04-22 16:51:13.264274
33	HM469	Approaches to Globalization	3	0	0	3	3-0-0-3	HASS Elective	2026-04-22 16:51:13.264274
34	SC421	Introduction to Modern Algebra	3	0	0	3	3-0-0-3	Science Elective	2026-04-22 16:51:13.264274
35	CT548	Advanced Wireless Communication	3	0	2	4	3-0-2-4	Technical Elective	2026-04-22 16:51:13.264274
36	IT549	Deep Learning	3	0	2	4	3-0-2-4	Technical Elective	2026-04-22 16:51:13.264274
37	IE416	Robot Programming	3	0	2	4	3-0-2-4	ICT & Technical Elective (RAS Core3)	2026-04-22 16:51:13.264274
38	IE423	AI Literacy, Efficiency, and Ethics	3	0	2	4	3-0-2-4	ICT & Technical Elective	2026-04-22 16:51:13.264274
39	SC301	Numerical Linear Algebra	3	0	0	3	3-0-0-3	Science Elective	2026-04-22 16:51:13.264274
40	EL527	ASIC Design	3	0	2	4	3-0-2-4	Technical Elective	2026-04-22 16:51:13.264274
41	IT449	Specification and Verification of Systems	3	0	0	3	3-0-0-3	Technical Elective	2026-04-22 16:51:13.264274
42	IT584	Approximation Algorithms	3	0	2	4	3-0-2-4	Technical Elective	2026-04-22 16:51:13.264274
43	HM377	The English Novel: Form and History	3	0	0	3	3-0-0-3	HASS Elective	2026-04-22 16:51:13.264274
44	SC475	Time Series Analysis	3	0	0	3	3-0-0-3	Science Elective	2026-04-22 16:51:13.264274
45	EL495	Sensors and Instrumentation	3	0	2	4	3-0-2-4	Technical Elective	2026-04-22 16:51:13.264274
46	IT565	Reinforecement Learning	3	0	2	4	3-0-2-4	Technical Elective	2026-04-22 16:51:13.264274
47	HM409	Management Skills for Professional Excellence	3	0	0	3	3-0-0-3	HASS Elective	2026-04-22 16:51:13.264274
48	SC444	Game Theory	3	0	0	3	3-0-0-3	Science Elective	2026-04-22 16:51:13.264274
49	EL464	VLSI Testing and Validation	3	0	2	4	3-0-2-4	Technical Elective	2026-04-22 16:51:13.264274
50	CT423	Wavelet Signal Processing	3	0	0	3	3-0-0-3	Technical Elective	2026-04-22 16:51:13.264274
51	IT590	Advanced Statistical Tools for Data Science	3	1	0	4	3-1-0-4	Technical Elective	2026-04-22 16:51:13.264274
52	IT401	Quantum ML	3	0	2	4	3-0-2-4	Technical Elective	2026-04-22 16:51:13.264274
53	IE411	Operating Systems	3	0	2	4	3-0-2-4	ICT & Technical Elective	2026-04-22 16:51:13.264274
54	HM481	Reading Plato	3	0	0	3	3-0-0-3	HASS Elective	2026-04-22 16:51:13.264274
55	SC409	Introduction to Financial Mathematics (ICT only)	3	1	0	4	3-1-0-4	Science Elective	2026-04-22 16:51:13.264274
56	IT507	Advanced Image Processing	3	0	2	4	3-0-2-4	Technical Elective	2026-04-22 16:51:13.264274
57	IT499	Biometric Security	3	0	2	4	3-0-2-4	Technical Elective	2026-04-22 16:51:13.264274
58	IT504	Distributed Databases	3	0	2	4	3-0-2-4	Technical Elective	2026-04-22 16:51:13.264274
59	HM414	A Beginner's Introduction to the Psyche	3	0	0	3	3-0-0-3	HASS Elective	2026-04-22 16:51:13.264274
60	SC402	Introduction To Cryptography	3	0	0	3	3-0-0-3	Science Elective	2026-04-22 16:51:13.264274
61	IT402	Applied Forecasting Methods	3	0	2	4	3-0-2-4	Technical Elective	2026-04-22 16:51:13.264274
62	HM402	Publics in South Asia: Contemporary Perspectives	3	0	0	3	3-0-0-3	HASS Elective	2026-04-22 16:51:13.264274
63	IE406	Machine Learning	3	0	2	4	3-0-2-4	ICT & Technical Elective	2026-04-22 16:51:13.264274
64	IT568	GenAI for Software Engineering	2	0	4	4	2-0-4-4	Technical Elective	2026-04-22 16:51:13.264274
65	IE407	Internet of Things	3	0	2	4	3-0-2-4	ICT & Technical Elective (RAS Elective)	2026-04-22 16:51:13.264274
66	SC463	Quantum Computation	3	0	0	3	3-0-0-3	Science Elective	2026-04-22 16:51:13.264274
67	IT443	Resampling Techniques and Bayesian Computation	3	0	2	4	3-0-2-4	Technical Elective	2026-04-22 16:51:13.264274
68	HM413	Knowledge and Identity in Three Modern Indian Novels	3	0	0	3	3-0-0-3	HASS Elective	2026-04-22 16:51:13.264274
69	IT414	Software Project Management	3	0	2	4	3-0-2-4	Technical Elective	2026-04-22 16:51:13.264274
70	HM412	World Literature in Short Fiction	3	0	0	3	3-0-0-3	HASS Elective	2026-04-22 16:51:13.264274
71	HM495	Technology and The Making of Modern India	3	0	0	3	3-0-0-3	HASS Elective	2026-04-22 16:51:13.264274
72	HM494	Indian Diaspora and Transnationalism	3	0	0	3	3-0-0-3	HASS Elective	2026-04-22 16:51:13.264274
73	HM 489	International Economics	3	0	0	3	3-0-0-3	HASS Elective	2026-04-22 16:51:13.264274
74	CS302	Modeling and Simulation	3	0	3	4	3-0-3-4.5	Core	2026-04-22 16:51:13.264274
75	CS408	Computational Finance	3	0	0	3	3-0-0-3	Science Elective	2026-04-22 16:51:13.264274
76	CS301	High Performance Computing	3	0	3	4	3-0-3-4.5	Core	2026-04-22 16:51:13.264274
77	MC321	Machine Learning	3	0	2	4	3-0-2-4	Core	2026-04-22 16:51:13.264274
78	EL435	Analog and Mixed Signal IC	0	0	0	0	nan	Specialization Elective-3	2026-04-22 16:51:13.264274
79	ED322	VLSI Testing and Validation	3	0	2	4	3-0-2-4	Core	2026-04-22 16:51:13.264274
80	IT561	Advanced Software Engineering	3	0	2	4	3-0-2-4	SS Sp. Core	2026-04-22 16:51:13.264274
81	IT585	Advanced Machine Learning	3	0	2	4	3-0-2-4	ML Sp. Core	2026-04-22 16:51:13.264274
82	EL529	Embedded Hardware Design	3	0	2	4	3-0-2-4	VES Sp. Core	2026-04-22 16:51:13.264274
83	IT620	Object Oriented Programming	3	0	2	4	3-0-2-4	Core	2026-04-22 16:51:13.264274
84	IT632	Software Engineering	3	0	2	4	3-0-2-4	Core	2026-04-22 16:51:13.264274
85	IT694	Computer Networks	3	0	2	4	3-0-2-4	Core	2026-04-22 16:51:13.264274
86	IT628	System Programming	3	0	2	4	3-0-2-4	Core	2026-04-22 16:51:13.264274
87	IT637	Introduction to Algorithms	3	0	2	4	3-0-2-4	Core	2026-04-22 16:51:13.264274
88	DS611	Numerical Optimization	2	0	2	3	2-0-2-3	Core	2026-04-22 16:51:13.264274
89	DS614	Big Data Engineering	3	0	2	4	3-0-2-4	Core	2026-04-22 16:51:13.264274
90	DS612	Interactive Data Visualization	3	0	2	4	3-0-2-4	Core	2026-04-22 16:51:13.264274
91	DS615	Neural Netwroks and Deep Learning	3	0	2	4	3-0-2-4	Core	2026-04-22 16:51:13.264274
\.


--
-- Data for Name: faculty; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.faculty (faculty_id, name, short_name, department, email, created_at) FROM stdin;
1	\N	AB	\N	\N	2026-04-22 16:51:13.264274
2	\N	AC	\N	\N	2026-04-22 16:51:13.264274
3	\N	AC1	\N	\N	2026-04-22 16:51:13.264274
4	\N	AG	\N	\N	2026-04-22 16:51:13.264274
5	\N	AG1	\N	\N	2026-04-22 16:51:13.264274
6	\N	AJ	\N	\N	2026-04-22 16:51:13.264274
7	\N	AKT	\N	\N	2026-04-22 16:51:13.264274
8	\N	AM	\N	\N	2026-04-22 16:51:13.264274
9	\N	AM2	\N	\N	2026-04-22 16:51:13.264274
10	\N	AMK	\N	\N	2026-04-22 16:51:13.264274
11	\N	AMM	\N	\N	2026-04-22 16:51:13.264274
12	\N	AR	\N	\N	2026-04-22 16:51:13.264274
13	\N	AR2	\N	\N	2026-04-22 16:51:13.264274
14	\N	AT	\N	\N	2026-04-22 16:51:13.264274
15	\N	AT3	\N	\N	2026-04-22 16:51:13.264274
16	\N	AV	\N	\N	2026-04-22 16:51:13.264274
17	\N	BC	\N	\N	2026-04-22 16:51:13.264274
18	\N	BK	\N	\N	2026-04-22 16:51:13.264274
19	\N	BM	\N	\N	2026-04-22 16:51:13.264274
20	\N	CJ	\N	\N	2026-04-22 16:51:13.264274
21	\N	GD	\N	\N	2026-04-22 16:51:13.264274
22	\N	GM	\N	\N	2026-04-22 16:51:13.264274
23	\N	GP	\N	\N	2026-04-22 16:51:13.264274
24	\N	GV	\N	\N	2026-04-22 16:51:13.264274
25	\N	HP	\N	\N	2026-04-22 16:51:13.264274
26	\N	HSJ	\N	\N	2026-04-22 16:51:13.264274
27	\N	JJ	\N	\N	2026-04-22 16:51:13.264274
28	\N	JL	\N	\N	2026-04-22 16:51:13.264274
29	\N	KD	\N	\N	2026-04-22 16:51:13.264274
30	\N	MB	\N	\N	2026-04-22 16:51:13.264274
31	\N	MC	\N	\N	2026-04-22 16:51:13.264274
32	\N	MK2	\N	\N	2026-04-22 16:51:13.264274
33	\N	MKR	\N	\N	2026-04-22 16:51:13.264274
34	\N	MLD	\N	\N	2026-04-22 16:51:13.264274
35	\N	MM	\N	\N	2026-04-22 16:51:13.264274
36	\N	MS	\N	\N	2026-04-22 16:51:13.264274
37	\N	MT	\N	\N	2026-04-22 16:51:13.264274
38	\N	MVJ	\N	\N	2026-04-22 16:51:13.264274
39	\N	NB	\N	\N	2026-04-22 16:51:13.264274
40	\N	NKS	\N	\N	2026-04-22 16:51:13.264274
41	\N	PA	\N	\N	2026-04-22 16:51:13.264274
42	\N	PB	\N	\N	2026-04-22 16:51:13.264274
43	\N	PD	\N	\N	2026-04-22 16:51:13.264274
44	\N	PG	\N	\N	2026-04-22 16:51:13.264274
45	\N	PK	\N	\N	2026-04-22 16:51:13.264274
46	\N	PK2	\N	\N	2026-04-22 16:51:13.264274
47	\N	PK3	\N	\N	2026-04-22 16:51:13.264274
48	\N	PKS	\N	\N	2026-04-22 16:51:13.264274
49	\N	PMJ	\N	\N	2026-04-22 16:51:13.264274
50	\N	PR	\N	\N	2026-04-22 16:51:13.264274
51	\N	RB	\N	\N	2026-04-22 16:51:13.264274
52	\N	RC	\N	\N	2026-04-22 16:51:13.264274
53	\N	RLD	\N	\N	2026-04-22 16:51:13.264274
54	\N	RM	\N	\N	2026-04-22 16:51:13.264274
55	\N	RP	\N	\N	2026-04-22 16:51:13.264274
56	\N	SB	\N	\N	2026-04-22 16:51:13.264274
57	\N	SB2	\N	\N	2026-04-22 16:51:13.264274
58	\N	SB3	\N	\N	2026-04-22 16:51:13.264274
59	\N	SCN	\N	\N	2026-04-22 16:51:13.264274
60	\N	SDG	\N	\N	2026-04-22 16:51:13.264274
61	\N	SG	\N	\N	2026-04-22 16:51:13.264274
62	\N	SJ	\N	\N	2026-04-22 16:51:13.264274
63	\N	SK	\N	\N	2026-04-22 16:51:13.264274
64	\N	SM	\N	\N	2026-04-22 16:51:13.264274
65	\N	SM1	\N	\N	2026-04-22 16:51:13.264274
66	\N	SP	\N	\N	2026-04-22 16:51:13.264274
67	\N	SR	\N	\N	2026-04-22 16:51:13.264274
68	\N	SS	\N	\N	2026-04-22 16:51:13.264274
69	\N	ST	\N	\N	2026-04-22 16:51:13.264274
70	\N	TB	\N	\N	2026-04-22 16:51:13.264274
71	\N	TKM	\N	\N	2026-04-22 16:51:13.264274
72	\N	VF	\N	\N	2026-04-22 16:51:13.264274
73	\N	VS	\N	\N	2026-04-22 16:51:13.264274
74	\N	VSP	\N	\N	2026-04-22 16:51:13.264274
75	\N	YA	\N	\N	2026-04-22 16:51:13.264274
76	\N	YV	\N	\N	2026-04-22 16:51:13.264274
\.


--
-- Data for Name: faculty_course_map; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.faculty_course_map (assignment_id, faculty_id, course_id, created_at) FROM stdin;
1	1	45	2026-04-22 16:51:13.264274
2	2	89	2026-04-22 16:51:13.264274
3	3	63	2026-04-22 16:51:13.264274
4	4	25	2026-04-22 16:51:13.264274
5	5	53	2026-04-22 16:51:13.264274
6	6	46	2026-04-22 16:51:13.264274
7	7	55	2026-04-22 16:51:13.264274
8	8	43	2026-04-22 16:51:13.264274
9	9	9	2026-04-22 16:51:13.264274
10	10	87	2026-04-22 16:51:13.264274
11	11	86	2026-04-22 16:51:13.264274
12	12	74	2026-04-22 16:51:13.264274
13	12	75	2026-04-22 16:51:13.264274
14	13	3	2026-04-22 16:51:13.264274
15	13	36	2026-04-22 16:51:13.264274
16	14	5	2026-04-22 16:51:13.264274
17	14	39	2026-04-22 16:51:13.264274
18	15	47	2026-04-22 16:51:13.264274
19	16	10	2026-04-22 16:51:13.264274
20	17	76	2026-04-22 16:51:13.264274
21	17	90	2026-04-22 16:51:13.264274
22	18	54	2026-04-22 16:51:13.264274
23	18	32	2026-04-22 16:51:13.264274
24	19	22	2026-04-22 16:51:13.264274
25	20	73	2026-04-22 16:51:13.264274
26	20	17	2026-04-22 16:51:13.264274
27	21	34	2026-04-22 16:51:13.264274
28	21	66	2026-04-22 16:51:13.264274
29	22	68	2026-04-22 16:51:13.264274
30	23	30	2026-04-22 16:51:13.264274
31	24	48	2026-04-22 16:51:13.264274
32	25	50	2026-04-22 16:51:13.264274
33	26	24	2026-04-22 16:51:13.264274
34	27	59	2026-04-22 16:51:13.264274
35	28	80	2026-04-22 16:51:13.264274
36	28	84	2026-04-22 16:51:13.264274
37	29	7	2026-04-22 16:51:13.264274
38	30	58	2026-04-22 16:51:13.264274
39	31	65	2026-04-22 16:51:13.264274
40	32	35	2026-04-22 16:51:13.264274
41	32	16	2026-04-22 16:51:13.264274
42	33	88	2026-04-22 16:51:13.264274
43	34	11	2026-04-22 16:51:13.264274
44	34	60	2026-04-22 16:51:13.264274
45	35	33	2026-04-22 16:51:13.264274
46	36	12	2026-04-22 16:51:13.264274
47	36	16	2026-04-22 16:51:13.264274
48	37	44	2026-04-22 16:51:13.264274
49	38	52	2026-04-22 16:51:13.264274
50	39	26	2026-04-22 16:51:13.264274
51	40	28	2026-04-22 16:51:13.264274
52	41	61	2026-04-22 16:51:13.264274
53	42	41	2026-04-22 16:51:13.264274
54	42	31	2026-04-22 16:51:13.264274
55	43	1	2026-04-22 16:51:13.264274
56	43	71	2026-04-22 16:51:13.264274
57	44	17	2026-04-22 16:51:13.264274
58	45	2	2026-04-22 16:51:13.264274
59	46	8	2026-04-22 16:51:13.264274
60	47	19	2026-04-22 16:51:13.264274
61	48	85	2026-04-22 16:51:13.264274
62	49	14	2026-04-22 16:51:13.264274
63	50	21	2026-04-22 16:51:13.264274
64	50	6	2026-04-22 16:51:13.264274
65	51	1	2026-04-22 16:51:13.264274
66	51	72	2026-04-22 16:51:13.264274
67	52	42	2026-04-22 16:51:13.264274
68	52	81	2026-04-22 16:51:13.264274
69	53	6	2026-04-22 16:51:13.264274
70	54	5	2026-04-22 16:51:13.264274
71	55	23	2026-04-22 16:51:13.264274
72	55	40	2026-04-22 16:51:13.264274
73	56	57	2026-04-22 16:51:13.264274
74	57	27	2026-04-22 16:51:13.264274
75	58	67	2026-04-22 16:51:13.264274
76	59	20	2026-04-22 16:51:13.264274
77	60	91	2026-04-22 16:51:13.264274
78	60	83	2026-04-22 16:51:13.264274
79	61	70	2026-04-22 16:51:13.264274
80	62	62	2026-04-22 16:51:13.264274
81	63	18	2026-04-22 16:51:13.264274
82	64	56	2026-04-22 16:51:13.264274
83	64	77	2026-04-22 16:51:13.264274
84	65	4	2026-04-22 16:51:13.264274
85	66	3	2026-04-22 16:51:13.264274
86	67	79	2026-04-22 16:51:13.264274
87	67	49	2026-04-22 16:51:13.264274
88	67	2	2026-04-22 16:51:13.264274
89	68	38	2026-04-22 16:51:13.264274
90	69	64	2026-04-22 16:51:13.264274
91	70	51	2026-04-22 16:51:13.264274
92	71	13	2026-04-22 16:51:13.264274
93	71	37	2026-04-22 16:51:13.264274
94	72	78	2026-04-22 16:51:13.264274
95	72	69	2026-04-22 16:51:13.264274
96	73	29	2026-04-22 16:51:13.264274
97	74	82	2026-04-22 16:51:13.264274
98	75	13	2026-04-22 16:51:13.264274
99	76	15	2026-04-22 16:51:13.264274
\.


--
-- Data for Name: master_timetable; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.master_timetable (timetable_id, assignment_id, batch_id, room_id, slot_id, is_moved, original_slot_group, created_at) FROM stdin;
1	60	8	16	9	f	Slot-8	2026-04-22 16:51:13.560716
2	60	8	16	16	f	Slot-8	2026-04-22 16:51:13.560716
3	60	8	16	23	f	Slot-8	2026-04-22 16:51:13.560716
4	76	8	4	9	f	Slot-8	2026-04-22 16:51:13.560716
5	76	8	4	16	f	Slot-8	2026-04-22 16:51:13.560716
6	76	8	4	23	f	Slot-8	2026-04-22 16:51:13.560716
7	63	5	7	9	f	Slot-8	2026-04-22 16:51:13.560716
8	63	5	7	16	f	Slot-8	2026-04-22 16:51:13.560716
9	63	5	7	23	f	Slot-8	2026-04-22 16:51:13.560716
10	39	24	5	9	f	Slot-8	2026-04-22 16:51:13.560716
11	39	24	5	16	f	Slot-8	2026-04-22 16:51:13.560716
12	39	24	5	23	f	Slot-8	2026-04-22 16:51:13.560716
13	88	3	11	8	f	Slot-2	2026-04-22 16:51:13.560716
14	88	3	11	17	f	Slot-2	2026-04-22 16:51:13.560716
15	88	3	11	24	f	Slot-2	2026-04-22 16:51:13.560716
16	62	7	10	8	f	Slot-2	2026-04-22 16:51:13.560716
17	62	7	10	17	f	Slot-2	2026-04-22 16:51:13.560716
18	62	7	10	24	f	Slot-2	2026-04-22 16:51:13.560716
19	34	23	16	8	f	Slot-2	2026-04-22 16:51:13.560716
20	34	23	16	17	f	Slot-2	2026-04-22 16:51:13.560716
21	34	23	16	24	f	Slot-2	2026-04-22 16:51:13.560716
22	12	17	7	8	f	Slot-2	2026-04-22 16:51:13.560716
23	12	17	7	17	f	Slot-2	2026-04-22 16:51:13.560716
24	12	17	7	24	f	Slot-2	2026-04-22 16:51:13.560716
25	41	8	12	2	f	Slot-5	2026-04-22 16:51:13.560716
26	41	8	12	10	f	Slot-5	2026-04-22 16:51:13.560716
27	41	8	12	18	f	Slot-5	2026-04-22 16:51:13.560716
28	13	17	7	2	f	Slot-5	2026-04-22 16:51:13.560716
29	13	17	7	10	f	Slot-5	2026-04-22 16:51:13.560716
30	13	17	7	18	f	Slot-5	2026-04-22 16:51:13.560716
31	23	18	19	1	f	Slot-1	2026-04-22 16:51:13.560716
32	23	18	19	14	f	Slot-1	2026-04-22 16:51:13.560716
33	23	18	19	22	f	Slot-1	2026-04-22 16:51:13.560716
34	86	10	9	3	f	Slot-4	2026-04-22 16:51:13.560716
35	86	10	9	13	f	Slot-4	2026-04-22 16:51:13.560716
36	86	10	9	21	f	Slot-4	2026-04-22 16:51:13.560716
37	93	18	6	9	f	Slot-8	2026-04-22 16:51:13.560716
38	93	18	6	16	f	Slot-8	2026-04-22 16:51:13.560716
39	93	18	6	23	f	Slot-8	2026-04-22 16:51:13.560716
40	84	2	10	3	f	Slot-4	2026-04-22 16:51:13.560716
41	84	2	10	13	f	Slot-4	2026-04-22 16:51:13.560716
42	84	2	10	21	f	Slot-4	2026-04-22 16:51:13.560716
43	33	6	3	2	f	Slot-5	2026-04-22 16:51:13.560716
44	33	6	3	10	f	Slot-5	2026-04-22 16:51:13.560716
45	33	6	3	18	f	Slot-5	2026-04-22 16:51:13.560716
46	17	19	15	6	f	Slot-3	2026-04-22 16:51:13.560716
47	17	19	15	15	f	Slot-3	2026-04-22 16:51:13.560716
48	17	19	15	25	f	Slot-3	2026-04-22 16:51:13.560716
49	50	9	7	1	f	Slot-1	2026-04-22 16:51:13.560716
50	50	9	7	14	f	Slot-1	2026-04-22 16:51:13.560716
51	50	9	7	22	f	Slot-1	2026-04-22 16:51:13.560716
52	15	18	16	5	f	Slot-6	2026-04-22 16:51:13.560716
53	15	18	16	12	f	Slot-6	2026-04-22 16:51:13.560716
54	15	18	16	20	f	Slot-6	2026-04-22 16:51:13.560716
55	72	19	5	5	t	Slot-5	2026-04-22 16:51:13.560716
56	72	19	5	12	t	Slot-5	2026-04-22 16:51:13.560716
57	72	19	5	20	t	Slot-5	2026-04-22 16:51:13.560716
58	83	30	1	1	f	Slot-1	2026-04-22 16:51:13.560716
59	83	30	1	14	f	Slot-1	2026-04-22 16:51:13.560716
60	83	30	1	22	f	Slot-1	2026-04-22 16:51:13.560716
61	55	2	18	1	f	Slot-1	2026-04-22 16:51:13.560716
62	55	2	18	14	f	Slot-1	2026-04-22 16:51:13.560716
63	55	2	18	22	f	Slot-1	2026-04-22 16:51:13.560716
64	92	8	11	1	f	Slot-1	2026-04-22 16:51:13.560716
65	92	8	11	14	f	Slot-1	2026-04-22 16:51:13.560716
66	92	8	11	22	f	Slot-1	2026-04-22 16:51:13.560716
67	45	18	14	8	f	Slot-2	2026-04-22 16:51:13.560716
68	45	18	14	17	f	Slot-2	2026-04-22 16:51:13.560716
69	45	18	14	24	f	Slot-2	2026-04-22 16:51:13.560716
70	40	18	14	3	f	Slot-4	2026-04-22 16:51:13.560716
71	40	18	14	13	f	Slot-4	2026-04-22 16:51:13.560716
72	40	18	14	21	f	Slot-4	2026-04-22 16:51:13.560716
73	52	23	14	5	f	Slot-6	2026-04-22 16:51:13.560716
74	52	23	14	12	f	Slot-6	2026-04-22 16:51:13.560716
75	52	23	14	20	f	Slot-6	2026-04-22 16:51:13.560716
76	56	28	15	8	f	Slot-2	2026-04-22 16:51:13.560716
77	56	28	15	17	f	Slot-2	2026-04-22 16:51:13.560716
78	56	28	15	24	f	Slot-2	2026-04-22 16:51:13.560716
79	65	3	17	1	f	Slot-1	2026-04-22 16:51:13.560716
80	65	3	17	14	f	Slot-1	2026-04-22 16:51:13.560716
81	65	3	17	22	f	Slot-1	2026-04-22 16:51:13.560716
82	99	7	10	6	f	Slot-3	2026-04-22 16:51:13.560716
83	99	7	10	15	f	Slot-3	2026-04-22 16:51:13.560716
84	99	7	10	25	f	Slot-3	2026-04-22 16:51:13.560716
85	71	6	9	6	t	Slot-4	2026-04-22 16:51:13.560716
86	71	6	9	15	t	Slot-4	2026-04-22 16:51:13.560716
87	71	6	9	25	t	Slot-4	2026-04-22 16:51:13.560716
88	27	18	1	6	f	Slot-3	2026-04-22 16:51:13.560716
89	27	18	1	15	f	Slot-3	2026-04-22 16:51:13.560716
90	27	18	1	25	f	Slot-3	2026-04-22 16:51:13.560716
91	79	27	15	4	f	Slot-7	2026-04-22 16:51:13.560716
92	79	27	15	7	f	Slot-7	2026-04-22 16:51:13.560716
93	79	27	15	19	f	Slot-7	2026-04-22 16:51:13.560716
94	35	71	14	1	f	Slot-1	2026-04-22 16:51:13.560716
95	35	71	14	14	f	Slot-1	2026-04-22 16:51:13.560716
96	35	71	14	22	f	Slot-1	2026-04-22 16:51:13.560716
97	85	3	11	6	f	Slot-3	2026-04-22 16:51:13.560716
98	85	3	11	15	f	Slot-3	2026-04-22 16:51:13.560716
99	85	3	11	25	f	Slot-3	2026-04-22 16:51:13.560716
100	16	3	12	5	f	Slot-6	2026-04-22 16:51:13.560716
101	16	3	12	12	f	Slot-6	2026-04-22 16:51:13.560716
102	16	3	12	20	f	Slot-6	2026-04-22 16:51:13.560716
103	69	3	11	4	f	Slot-7	2026-04-22 16:51:13.560716
104	69	3	11	7	f	Slot-7	2026-04-22 16:51:13.560716
105	69	3	11	19	f	Slot-7	2026-04-22 16:51:13.560716
106	59	1	9	5	f	Slot-6	2026-04-22 16:51:13.560716
107	59	1	9	12	f	Slot-6	2026-04-22 16:51:13.560716
108	59	1	9	20	f	Slot-6	2026-04-22 16:51:13.560716
109	43	4	1	2	f	Slot-5	2026-04-22 16:51:13.560716
110	43	4	1	10	f	Slot-5	2026-04-22 16:51:13.560716
111	43	4	1	18	f	Slot-5	2026-04-22 16:51:13.560716
112	46	4	7	4	f	Slot-7	2026-04-22 16:51:13.560716
113	46	4	7	7	f	Slot-7	2026-04-22 16:51:13.560716
114	46	4	7	19	f	Slot-7	2026-04-22 16:51:13.560716
115	24	6	4	3	t	Slot-3	2026-04-22 16:51:13.560716
116	24	6	4	13	t	Slot-3	2026-04-22 16:51:13.560716
117	24	6	4	21	t	Slot-3	2026-04-22 16:51:13.560716
118	4	6	4	5	f	Slot-6	2026-04-22 16:51:13.560716
119	4	6	4	12	f	Slot-6	2026-04-22 16:51:13.560716
120	4	6	4	20	f	Slot-6	2026-04-22 16:51:13.560716
121	54	9	1	9	f	Slot-8	2026-04-22 16:51:13.560716
122	54	9	1	16	f	Slot-8	2026-04-22 16:51:13.560716
123	54	9	1	23	f	Slot-8	2026-04-22 16:51:13.560716
124	53	19	13	5	f	Slot-6	2026-04-22 16:51:13.560716
125	53	19	13	12	f	Slot-6	2026-04-22 16:51:13.560716
126	53	19	13	20	f	Slot-6	2026-04-22 16:51:13.560716
127	67	19	1	4	f	Slot-7	2026-04-22 16:51:13.560716
128	67	19	1	7	f	Slot-7	2026-04-22 16:51:13.560716
129	67	19	1	19	f	Slot-7	2026-04-22 16:51:13.560716
130	48	20	16	6	f	Slot-3	2026-04-22 16:51:13.560716
131	48	20	16	15	f	Slot-3	2026-04-22 16:51:13.560716
132	48	20	16	25	f	Slot-3	2026-04-22 16:51:13.560716
133	18	21	3	8	f	Slot-2	2026-04-22 16:51:13.560716
134	18	21	3	17	f	Slot-2	2026-04-22 16:51:13.560716
135	18	21	3	24	f	Slot-2	2026-04-22 16:51:13.560716
136	87	21	3	1	t	Slot-4	2026-04-22 16:51:13.560716
137	87	21	3	14	t	Slot-4	2026-04-22 16:51:13.560716
138	87	21	3	22	t	Slot-4	2026-04-22 16:51:13.560716
139	32	21	5	2	f	Slot-5	2026-04-22 16:51:13.560716
140	32	21	5	10	f	Slot-5	2026-04-22 16:51:13.560716
141	32	21	5	18	f	Slot-5	2026-04-22 16:51:13.560716
142	91	21	4	4	t	Slot-6	2026-04-22 16:51:13.560716
143	91	21	4	7	t	Slot-6	2026-04-22 16:51:13.560716
144	91	21	4	19	t	Slot-6	2026-04-22 16:51:13.560716
145	44	23	14	6	f	Slot-3	2026-04-22 16:51:13.560716
146	44	23	14	15	f	Slot-3	2026-04-22 16:51:13.560716
147	44	23	14	25	f	Slot-3	2026-04-22 16:51:13.560716
148	95	26	1	5	f	Slot-6	2026-04-22 16:51:13.560716
149	95	26	1	12	f	Slot-6	2026-04-22 16:51:13.560716
150	95	26	1	20	f	Slot-6	2026-04-22 16:51:13.560716
151	68	67	16	1	f	Slot-1	2026-04-22 16:51:13.560716
152	68	67	16	14	f	Slot-1	2026-04-22 16:51:13.560716
153	68	67	16	22	f	Slot-1	2026-04-22 16:51:13.560716
154	9	4	7	6	t	Slot-2	2026-04-22 16:51:13.560716
155	9	4	7	15	t	Slot-2	2026-04-22 16:51:13.560716
156	9	4	7	25	t	Slot-2	2026-04-22 16:51:13.560716
157	19	4	7	3	t	Slot-3	2026-04-22 16:51:13.560716
158	19	4	7	13	t	Slot-3	2026-04-22 16:51:13.560716
159	19	4	7	21	t	Slot-3	2026-04-22 16:51:13.560716
160	74	9	1	8	f	Slot-2	2026-04-22 16:51:13.560716
161	74	9	1	17	f	Slot-2	2026-04-22 16:51:13.560716
162	74	9	1	24	f	Slot-2	2026-04-22 16:51:13.560716
163	51	9	1	3	f	Slot-4	2026-04-22 16:51:13.560716
164	51	9	1	13	f	Slot-4	2026-04-22 16:51:13.560716
165	51	9	1	21	f	Slot-4	2026-04-22 16:51:13.560716
166	96	9	14	2	f	Slot-5	2026-04-22 16:51:13.560716
167	96	9	14	10	f	Slot-5	2026-04-22 16:51:13.560716
168	96	9	14	18	f	Slot-5	2026-04-22 16:51:13.560716
169	30	9	7	5	f	Slot-6	2026-04-22 16:51:13.560716
170	30	9	7	12	f	Slot-6	2026-04-22 16:51:13.560716
171	30	9	7	20	f	Slot-6	2026-04-22 16:51:13.560716
172	6	20	9	4	f	Slot-7	2026-04-22 16:51:13.560716
173	6	20	9	7	f	Slot-7	2026-04-22 16:51:13.560716
174	6	20	9	19	f	Slot-7	2026-04-22 16:51:13.560716
175	49	21	12	4	f	Slot-7	2026-04-22 16:51:13.560716
176	49	21	12	7	f	Slot-7	2026-04-22 16:51:13.560716
177	49	21	12	19	f	Slot-7	2026-04-22 16:51:13.560716
178	82	22	6	5	f	Slot-6	2026-04-22 16:51:13.560716
179	82	22	6	12	f	Slot-6	2026-04-22 16:51:13.560716
180	82	22	6	20	f	Slot-6	2026-04-22 16:51:13.560716
181	25	29	10	1	t	Slot-7	2026-04-22 16:51:13.560716
182	25	29	10	14	t	Slot-7	2026-04-22 16:51:13.560716
183	25	29	10	22	t	Slot-7	2026-04-22 16:51:13.560716
184	97	74	4	2	t	Slot-1	2026-04-22 16:51:13.560716
185	97	74	4	10	t	Slot-1	2026-04-22 16:51:13.560716
186	97	74	4	18	t	Slot-1	2026-04-22 16:51:13.560716
187	14	2	2	6	f	Slot-3	2026-04-22 16:51:13.560716
188	14	2	2	15	f	Slot-3	2026-04-22 16:51:13.560716
189	14	2	2	25	f	Slot-3	2026-04-22 16:51:13.560716
190	64	2	10	4	f	Slot-7	2026-04-22 16:51:13.560716
191	64	2	10	7	f	Slot-7	2026-04-22 16:51:13.560716
192	64	2	10	19	f	Slot-7	2026-04-22 16:51:13.560716
193	47	7	2	1	t	Slot-5	2026-04-22 16:51:13.560716
194	47	7	2	14	t	Slot-5	2026-04-22 16:51:13.560716
195	47	7	2	22	t	Slot-5	2026-04-22 16:51:13.560716
196	26	7	10	5	f	Slot-6	2026-04-22 16:51:13.560716
197	26	7	10	12	f	Slot-6	2026-04-22 16:51:13.560716
198	26	7	10	20	f	Slot-6	2026-04-22 16:51:13.560716
199	5	21	8	2	t	Slot-8	2026-04-22 16:51:13.560716
200	5	21	8	10	t	Slot-8	2026-04-22 16:51:13.560716
201	5	21	8	18	t	Slot-8	2026-04-22 16:51:13.560716
202	38	22	5	4	t	Slot-8	2026-04-22 16:51:13.560716
203	38	22	5	7	t	Slot-8	2026-04-22 16:51:13.560716
204	38	22	5	19	t	Slot-8	2026-04-22 16:51:13.560716
205	3	23	14	9	f	Slot-8	2026-04-22 16:51:13.560716
206	3	23	14	16	f	Slot-8	2026-04-22 16:51:13.560716
207	3	23	14	23	f	Slot-8	2026-04-22 16:51:13.560716
208	28	25	16	2	f	Slot-5	2026-04-22 16:51:13.560716
209	28	25	16	10	f	Slot-5	2026-04-22 16:51:13.560716
210	28	25	16	18	f	Slot-5	2026-04-22 16:51:13.560716
211	77	62	5	1	t	Slot-4	2026-04-22 16:51:13.560716
212	77	62	5	14	t	Slot-4	2026-04-22 16:51:13.560716
213	77	62	5	22	t	Slot-4	2026-04-22 16:51:13.560716
214	58	2	2	8	f	Slot-2	2026-04-22 16:51:13.560716
215	58	2	2	17	f	Slot-2	2026-04-22 16:51:13.560716
216	58	2	2	24	f	Slot-2	2026-04-22 16:51:13.560716
217	70	2	2	5	f	Slot-6	2026-04-22 16:51:13.560716
218	70	2	2	12	f	Slot-6	2026-04-22 16:51:13.560716
219	70	2	2	20	f	Slot-6	2026-04-22 16:51:13.560716
220	98	7	10	2	t	Slot-1	2026-04-22 16:51:13.560716
221	98	7	10	10	t	Slot-1	2026-04-22 16:51:13.560716
222	98	7	10	18	t	Slot-1	2026-04-22 16:51:13.560716
223	81	7	10	9	f	Slot-8	2026-04-22 16:51:13.560716
224	81	7	10	16	f	Slot-8	2026-04-22 16:51:13.560716
225	81	7	10	23	f	Slot-8	2026-04-22 16:51:13.560716
226	57	8	3	5	f	Slot-6	2026-04-22 16:51:13.560716
227	57	8	3	12	f	Slot-6	2026-04-22 16:51:13.560716
228	57	8	3	20	f	Slot-6	2026-04-22 16:51:13.560716
229	8	20	4	8	f	Slot-2	2026-04-22 16:51:13.560716
230	8	20	4	17	f	Slot-2	2026-04-22 16:51:13.560716
231	8	20	4	24	f	Slot-2	2026-04-22 16:51:13.560716
232	22	22	9	8	f	Slot-2	2026-04-22 16:51:13.560716
233	22	22	9	17	f	Slot-2	2026-04-22 16:51:13.560716
234	22	22	9	24	f	Slot-2	2026-04-22 16:51:13.560716
235	66	28	3	4	f	Slot-7	2026-04-22 16:51:13.560716
236	66	28	3	7	f	Slot-7	2026-04-22 16:51:13.560716
237	66	28	3	19	f	Slot-7	2026-04-22 16:51:13.560716
238	78	66	8	5	t	Slot-1	2026-04-22 16:51:13.560716
239	78	66	8	12	t	Slot-1	2026-04-22 16:51:13.560716
240	78	66	8	20	t	Slot-1	2026-04-22 16:51:13.560716
241	36	66	8	8	f	Slot-2	2026-04-22 16:51:13.560716
242	36	66	8	17	f	Slot-2	2026-04-22 16:51:13.560716
243	36	66	8	24	f	Slot-2	2026-04-22 16:51:13.560716
244	42	62	5	3	t	Slot-1	2026-04-22 16:51:13.560716
245	42	62	5	13	t	Slot-1	2026-04-22 16:51:13.560716
246	42	62	5	21	t	Slot-1	2026-04-22 16:51:13.560716
247	2	62	5	8	f	Slot-2	2026-04-22 16:51:13.560716
248	2	62	5	17	f	Slot-2	2026-04-22 16:51:13.560716
249	2	62	5	24	f	Slot-2	2026-04-22 16:51:13.560716
250	21	62	5	6	f	Slot-3	2026-04-22 16:51:13.560716
251	21	62	5	15	f	Slot-3	2026-04-22 16:51:13.560716
252	21	62	5	25	f	Slot-3	2026-04-22 16:51:13.560716
253	1	20	9	2	f	Slot-5	2026-04-22 16:51:13.560716
254	1	20	9	10	f	Slot-5	2026-04-22 16:51:13.560716
255	1	20	9	18	f	Slot-5	2026-04-22 16:51:13.560716
256	31	21	6	6	f	Slot-3	2026-04-22 16:51:13.560716
257	31	21	6	15	f	Slot-3	2026-04-22 16:51:13.560716
258	31	21	6	25	f	Slot-3	2026-04-22 16:51:13.560716
259	80	23	8	4	f	Slot-7	2026-04-22 16:51:13.560716
260	80	23	8	7	f	Slot-7	2026-04-22 16:51:13.560716
261	80	23	8	19	f	Slot-7	2026-04-22 16:51:13.560716
262	90	24	15	5	f	Slot-6	2026-04-22 16:51:13.560716
263	90	24	15	12	f	Slot-6	2026-04-22 16:51:13.560716
264	90	24	15	20	f	Slot-6	2026-04-22 16:51:13.560716
265	29	25	9	9	t	Slot-7	2026-04-22 16:51:13.560716
266	29	25	9	16	t	Slot-7	2026-04-22 16:51:13.560716
267	29	25	9	23	t	Slot-7	2026-04-22 16:51:13.560716
268	94	10	4	6	f	Slot-3	2026-04-22 16:51:13.560716
269	94	10	4	15	f	Slot-3	2026-04-22 16:51:13.560716
270	94	10	4	25	f	Slot-3	2026-04-22 16:51:13.560716
271	61	66	8	6	f	Slot-3	2026-04-22 16:51:13.560716
272	61	66	8	15	f	Slot-3	2026-04-22 16:51:13.560716
273	61	66	8	25	f	Slot-3	2026-04-22 16:51:13.560716
274	11	66	8	3	f	Slot-4	2026-04-22 16:51:13.560716
275	11	66	8	13	f	Slot-4	2026-04-22 16:51:13.560716
276	11	66	8	21	f	Slot-4	2026-04-22 16:51:13.560716
277	10	66	8	9	t	Slot-5	2026-04-22 16:51:13.560716
278	10	66	8	16	t	Slot-5	2026-04-22 16:51:13.560716
279	10	66	8	23	t	Slot-5	2026-04-22 16:51:13.560716
280	75	25	3	6	t	Slot-6	2026-04-22 16:51:13.560716
281	75	25	3	15	t	Slot-6	2026-04-22 16:51:13.560716
282	75	25	3	25	t	Slot-6	2026-04-22 16:51:13.560716
283	7	22	14	4	t	Slot-3	2026-04-22 16:51:13.560716
284	7	22	14	7	t	Slot-3	2026-04-22 16:51:13.560716
285	7	22	14	19	t	Slot-3	2026-04-22 16:51:13.560716
286	73	22	16	4	f	Slot-7	2026-04-22 16:51:13.560716
287	73	22	16	7	f	Slot-7	2026-04-22 16:51:13.560716
288	73	22	16	19	f	Slot-7	2026-04-22 16:51:13.560716
\.


--
-- Data for Name: room; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.room (room_id, room_number, room_type, capacity, created_at) FROM stdin;
1	CEP003	Lecture Hall	60	2026-04-22 16:51:13.264274
2	CEP102	Lecture Hall	190	2026-04-22 16:51:13.264274
3	CEP103	Lecture Hall	110	2026-04-22 16:51:13.264274
4	CEP104	Lecture Hall	50	2026-04-22 16:51:13.264274
5	CEP105	Lecture Hall	90	2026-04-22 16:51:13.264274
6	CEP106	Lecture Hall	120	2026-04-22 16:51:13.264274
7	CEP107	Lecture Hall	60	2026-04-22 16:51:13.264274
8	CEP108	Lecture Hall	120	2026-04-22 16:51:13.264274
9	CEP109	Lecture Hall	40	2026-04-22 16:51:13.264274
10	CEP110	Lecture Hall	182	2026-04-22 16:51:13.264274
11	CEP202	Lecture Hall	150	2026-04-22 16:51:13.264274
12	CEP203	Lecture Hall	100	2026-04-22 16:51:13.264274
13	CEP204	Lecture Hall	120	2026-04-22 16:51:13.264274
14	CEP205	Lecture Hall	80	2026-04-22 16:51:13.264274
15	CEP206	Lecture Hall	90	2026-04-22 16:51:13.264274
16	CEP207	Lecture Hall	80	2026-04-22 16:51:13.264274
17	LT-1	Lecture Hall	200	2026-04-22 16:51:13.264274
18	LT-2	Lecture Hall	280	2026-04-22 16:51:13.264274
19	LT-3	Lecture Hall	330	2026-04-22 16:51:13.264274
\.


--
-- Data for Name: scheduling_constraint; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.scheduling_constraint (constraint_id, constraint_name, constraint_type, scope, rule_description, enforcement_level, is_active, parameters_json, created_at) FROM stdin;
1	No Faculty Double-Booking	HARD	FACULTY	A faculty member shall not be scheduled to teach in two different rooms or sections at the exact same time period.	DATABASE	t	{"enforced_by": "UNIQUE(assignment_id, slot_id) on master_timetable"}	2026-04-22 16:51:11.888449
2	No Room Double-Booking	HARD	ROOM	A room shall not be assigned to more than one class in the same time period.	DATABASE	t	{"enforced_by": "UNIQUE(room_id, slot_id) on master_timetable"}	2026-04-22 16:51:11.888449
3	Core Course Non-Overlap	HARD	BATCH	Only one core course can be scheduled in a given time period for a specific batch/section. All students in the section must be able to attend.	APPLICATION	t	{"applies_to": "core_courses_only", "enforced_by": "CSP solver conflict graph"}	2026-04-22 16:51:11.888449
4	Wednesday 8AM Free	HARD	GLOBAL	No class shall be scheduled on Wednesday at 8:00 AM. This is a university-designated free period.	BOTH	t	{"day": "Wednesday", "time": "08:00", "enforced_by": "Slot-Free mapping in time_slot + CSP validation"}	2026-04-22 16:51:11.888449
5	Elective Same-Slot Allowed	HARD	BATCH	Multiple elective courses CAN be offered in the exact same time period for a batch. Students choose and attend only one. This is NOT a conflict.	APPLICATION	t	{"note": "Exception to the general no-overlap rule", "applies_to": "elective_courses_only"}	2026-04-22 16:51:11.888449
6	Room Capacity Check	HARD	ROOM	Room capacity must be greater than or equal to the enrolled batch/section strength. The system validates Room.capacity >= Student_Batch.headcount before assignment.	APPLICATION	t	{"enforced_by": "Application-layer query before room assignment"}	2026-04-22 16:51:11.888449
7	No Course Twice on Same Day	HARD	COURSE	A course shall not have more than one class scheduled on the same day.	APPLICATION	t	{"enforced_by": "CSP solver slot-day mapping validation"}	2026-04-22 16:51:11.888449
8	Morning Sessions Only	HARD	GLOBAL	Classes shall only be scheduled within the 24 available morning periods (8:00 AM to 12:50 PM). Afternoon sessions (2:00 PM+) are reserved for labs.	DATABASE	t	{"session": "morning", "enforced_by": "time_slot table only contains morning slots", "max_periods_per_week": 24}	2026-04-22 16:51:11.888449
9	Minimize Room Changes	SOFT	BATCH	Minimize room changes for a batch/section on any given day. Penalty applied for each room switch.	APPLICATION	t	{"enforced_by": "soft_score() in apply_soft_constraints()", "penalty_per_change": 2}	2026-04-22 16:51:11.888449
10	Space Out Lectures	SOFT	COURSE	Space out lectures for the same course across the week as evenly as possible.	APPLICATION	t	{"enforced_by": "soft_score() consecutive-day penalty in apply_soft_constraints()"}	2026-04-22 16:51:11.888449
11	Faculty No Consecutive Lectures	SOFT	FACULTY	Prevent faculty from being assigned to consecutive teaching periods to mitigate fatigue.	APPLICATION	t	{"enforced_by": "soft_score() will add penalty for back-to-back slots", "max_consecutive": 2}	2026-04-22 16:51:11.888449
\.


--
-- Data for Name: student_batch; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.student_batch (batch_id, program_name, sub_batch, section, year, headcount, created_at) FROM stdin;
1	BTech Sem-II	BTech Sem-II (EVD)	Sec B	\N	0	2026-04-22 16:51:13.264274
2	BTech Sem-II	BTech Sem-II (ICT + CS)	Sec A	\N	0	2026-04-22 16:51:13.264274
3	BTech Sem-II	BTech Sem-II (ICT + CS)	Sec B	\N	0	2026-04-22 16:51:13.264274
4	BTech Sem-II	BTech Sem-II (MnC)	Sec A	\N	0	2026-04-22 16:51:13.264274
5	BTech Sem-IV	BTech Sem-IV (CS-Only)	Sec A	\N	0	2026-04-22 16:51:13.264274
6	BTech Sem-IV	BTech Sem-IV (EVD)	Sec B	\N	0	2026-04-22 16:51:13.264274
7	BTech Sem-IV	BTech Sem-IV (ICT + CS)	Sec A	\N	0	2026-04-22 16:51:13.264274
8	BTech Sem-IV	BTech Sem-IV (ICT + CS)	Sec B	\N	0	2026-04-22 16:51:13.264274
9	BTech Sem-IV	BTech Sem-IV (MnC)	Sec A	\N	0	2026-04-22 16:51:13.264274
10	BTech Sem-VI	B Tech Sem-VI (EVD)	Sec A	\N	0	2026-04-22 16:51:13.264274
11	BTech Sem-VI	B Tech Sem-VI (EVD)	Sec B	\N	0	2026-04-22 16:51:13.264274
12	BTech Sem-VI	B Tech Sem-VI (EVD)	Sec C	\N	0	2026-04-22 16:51:13.264274
13	BTech Sem-VI	B Tech Sem-VI (EVD)	Sec D	\N	0	2026-04-22 16:51:13.264274
14	BTech Sem-VI	B Tech Sem-VI (EVD)	Sec E	\N	0	2026-04-22 16:51:13.264274
15	BTech Sem-VI	B Tech Sem-VI (EVD)	Sec F	\N	0	2026-04-22 16:51:13.264274
16	BTech Sem-VI	B Tech Sem-VI (EVD)	Sec I	\N	0	2026-04-22 16:51:13.264274
17	BTech Sem-VI	BTech Sem-VI (CS-Only)	Sec A	\N	0	2026-04-22 16:51:13.264274
18	BTech Sem-VI	BTech Sem-VI (ICT + CS)	Sec A	\N	0	2026-04-22 16:51:13.264274
19	BTech Sem-VI	BTech Sem-VI (ICT + CS)	Sec B	\N	0	2026-04-22 16:51:13.264274
20	BTech Sem-VI	BTech Sem-VI (ICT + CS)	Sec C	\N	0	2026-04-22 16:51:13.264274
21	BTech Sem-VI	BTech Sem-VI (ICT + CS)	Sec D	\N	0	2026-04-22 16:51:13.264274
22	BTech Sem-VI	BTech Sem-VI (ICT + CS)	Sec E	\N	0	2026-04-22 16:51:13.264274
23	BTech Sem-VI	BTech Sem-VI (ICT + CS)	Sec F	\N	0	2026-04-22 16:51:13.264274
24	BTech Sem-VI	BTech Sem-VI (ICT + CS)	Sec G	\N	0	2026-04-22 16:51:13.264274
25	BTech Sem-VI	BTech Sem-VI (ICT + CS)	Sec H	\N	0	2026-04-22 16:51:13.264274
26	BTech Sem-VI	BTech Sem-VI (ICT + CS)	Sec I	\N	0	2026-04-22 16:51:13.264274
27	BTech Sem-VI	BTech Sem-VI (ICT + CS)	Sec J	\N	0	2026-04-22 16:51:13.264274
28	BTech Sem-VI	BTech Sem-VI (ICT + CS)	Sec K	\N	0	2026-04-22 16:51:13.264274
29	BTech Sem-VI	BTech Sem-VI (ICT + CS)	Sec L	\N	0	2026-04-22 16:51:13.264274
30	BTech Sem-VI	BTech Sem-VI (MnC)	Sec A	\N	0	2026-04-22 16:51:13.264274
31	BTech Sem-VI	BTech Sem-VI (MnC)	Sec B	\N	0	2026-04-22 16:51:13.264274
32	BTech Sem-VI	BTech Sem-VI (MnC)	Sec C	\N	0	2026-04-22 16:51:13.264274
33	BTech Sem-VI	BTech Sem-VI (MnC)	Sec D	\N	0	2026-04-22 16:51:13.264274
34	BTech Sem-VI	BTech Sem-VI (MnC)	Sec E	\N	0	2026-04-22 16:51:13.264274
35	BTech Sem-VI	BTech Sem-VI (MnC)	Sec F	\N	0	2026-04-22 16:51:13.264274
36	BTech Sem-VI	BTech Sem-VI (MnC)	Sec G	\N	0	2026-04-22 16:51:13.264274
37	BTech Sem-VI	BTech Sem-VI (MnC)	Sec H	\N	0	2026-04-22 16:51:13.264274
38	BTech Sem-VI	BTech Sem-VI (MnC)	Sec J	\N	0	2026-04-22 16:51:13.264274
39	BTech Sem-VI	BTech Sem-VI (MnC)	Sec K	\N	0	2026-04-22 16:51:13.264274
40	BTech Sem-VI	BTech Sem-VI (MnC)	Sec L	\N	0	2026-04-22 16:51:13.264274
41	BTech Sem-VIII	BTech Sem-VIII (ICT + CS)	Sec A	\N	0	2026-04-22 16:51:13.264274
42	BTech Sem-VIII	BTech Sem-VIII (ICT + CS)	Sec B	\N	0	2026-04-22 16:51:13.264274
43	BTech Sem-VIII	BTech Sem-VIII (ICT + CS)	Sec C	\N	0	2026-04-22 16:51:13.264274
44	BTech Sem-VIII	BTech Sem-VIII (ICT + CS)	Sec D	\N	0	2026-04-22 16:51:13.264274
45	BTech Sem-VIII	BTech Sem-VIII (ICT + CS)	Sec E	\N	0	2026-04-22 16:51:13.264274
46	BTech Sem-VIII	BTech Sem-VIII (ICT + CS)	Sec F	\N	0	2026-04-22 16:51:13.264274
47	BTech Sem-VIII	BTech Sem-VIII (ICT + CS)	Sec G	\N	0	2026-04-22 16:51:13.264274
48	BTech Sem-VIII	BTech Sem-VIII (ICT + CS)	Sec H	\N	0	2026-04-22 16:51:13.264274
49	BTech Sem-VIII	BTech Sem-VIII (ICT + CS)	Sec I	\N	0	2026-04-22 16:51:13.264274
50	BTech Sem-VIII	BTech Sem-VIII (ICT + CS)	Sec K	\N	0	2026-04-22 16:51:13.264274
51	BTech Sem-VIII	BTech Sem-VIII (ICT + CS)	Sec M	\N	0	2026-04-22 16:51:13.264274
52	BTech Sem-VIII	BTech Sem-VIII (MnC)	Sec A	\N	0	2026-04-22 16:51:13.264274
53	BTech Sem-VIII	BTech Sem-VIII (MnC)	Sec B	\N	0	2026-04-22 16:51:13.264274
54	BTech Sem-VIII	BTech Sem-VIII (MnC)	Sec C	\N	0	2026-04-22 16:51:13.264274
55	BTech Sem-VIII	BTech Sem-VIII (MnC)	Sec D	\N	0	2026-04-22 16:51:13.264274
56	BTech Sem-VIII	BTech Sem-VIII (MnC)	Sec E	\N	0	2026-04-22 16:51:13.264274
57	BTech Sem-VIII	BTech Sem-VIII (MnC)	Sec F	\N	0	2026-04-22 16:51:13.264274
58	BTech Sem-VIII	BTech Sem-VIII (MnC)	Sec I	\N	0	2026-04-22 16:51:13.264274
59	BTech Sem-VIII	BTech Sem-VIII (MnC)	Sec J	\N	0	2026-04-22 16:51:13.264274
60	BTech Sem-VIII	BTech Sem-VIII (MnC)	Sec K	\N	0	2026-04-22 16:51:13.264274
61	BTech Sem-VIII	BTech Sem-VIII (MnC)	Sec L	\N	0	2026-04-22 16:51:13.264274
62	MSc Sem-II	MSc Sem-II (DS)	Sec A	\N	0	2026-04-22 16:51:13.264274
63	MSc Sem-II	MSc Sem-II (DS)	Sec B	\N	0	2026-04-22 16:51:13.264274
64	MSc Sem-II	MSc Sem-II (DS)	Sec C	\N	0	2026-04-22 16:51:13.264274
65	MSc Sem-II	MSc Sem-II (DS)	Sec D	\N	0	2026-04-22 16:51:13.264274
66	MSc Sem-II	MSc Sem-II (IT)	Sec A	\N	0	2026-04-22 16:51:13.264274
67	MTech Sem-II	MTech Sem-II (ICT-ML)	Sec A	\N	0	2026-04-22 16:51:13.264274
68	MTech Sem-II	MTech Sem-II (ICT-ML)	Sec B	\N	0	2026-04-22 16:51:13.264274
69	MTech Sem-II	MTech Sem-II (ICT-ML)	Sec C	\N	0	2026-04-22 16:51:13.264274
70	MTech Sem-II	MTech Sem-II (ICT-ML)	Sec D	\N	0	2026-04-22 16:51:13.264274
71	MTech Sem-II	MTech Sem-II (ICT-SS)	Sec A	\N	0	2026-04-22 16:51:13.264274
72	MTech Sem-II	MTech Sem-II (ICT-SS)	Sec B	\N	0	2026-04-22 16:51:13.264274
73	MTech Sem-II	MTech Sem-II (ICT-SS)	Sec C	\N	0	2026-04-22 16:51:13.264274
74	MTech Sem-II	MTech Sem-II (ICT-VLSI&ES)	Sec A	\N	0	2026-04-22 16:51:13.264274
75	MTech Sem-II	MTech Sem-II (ICT-VLSI&ES)	Sec B	\N	0	2026-04-22 16:51:13.264274
\.


--
-- Data for Name: time_slot; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.time_slot (slot_id, day_of_week, start_time, end_time, slot_group) FROM stdin;
1	Monday	08:00:00	08:50:00	Slot-1
2	Monday	09:00:00	09:50:00	Slot-5
3	Monday	10:00:00	10:50:00	Slot-4
4	Monday	11:00:00	11:50:00	Slot-7
5	Monday	12:00:00	12:50:00	Slot-6
6	Tuesday	08:00:00	08:50:00	Slot-3
7	Tuesday	09:00:00	09:50:00	Slot-7
8	Tuesday	10:00:00	10:50:00	Slot-2
9	Tuesday	11:00:00	11:50:00	Slot-8
10	Tuesday	12:00:00	12:50:00	Slot-5
11	Wednesday	08:00:00	08:50:00	Slot-Free
12	Wednesday	09:00:00	09:50:00	Slot-6
13	Wednesday	10:00:00	10:50:00	Slot-4
14	Wednesday	11:00:00	11:50:00	Slot-1
15	Wednesday	12:00:00	12:50:00	Slot-3
16	Thursday	08:00:00	08:50:00	Slot-8
17	Thursday	09:00:00	09:50:00	Slot-2
18	Thursday	10:00:00	10:50:00	Slot-5
19	Thursday	11:00:00	11:50:00	Slot-7
20	Thursday	12:00:00	12:50:00	Slot-6
21	Friday	08:00:00	08:50:00	Slot-4
22	Friday	09:00:00	09:50:00	Slot-1
23	Friday	10:00:00	10:50:00	Slot-8
24	Friday	11:00:00	11:50:00	Slot-2
25	Friday	12:00:00	12:50:00	Slot-3
\.


--
-- Name: constraint_violation_log_violation_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.constraint_violation_log_violation_id_seq', 1, false);


--
-- Name: course_course_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.course_course_id_seq', 91, true);


--
-- Name: faculty_course_map_assignment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.faculty_course_map_assignment_id_seq', 99, true);


--
-- Name: faculty_faculty_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.faculty_faculty_id_seq', 76, true);


--
-- Name: master_timetable_timetable_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.master_timetable_timetable_id_seq', 288, true);


--
-- Name: room_room_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.room_room_id_seq', 19, true);


--
-- Name: scheduling_constraint_constraint_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.scheduling_constraint_constraint_id_seq', 11, true);


--
-- Name: student_batch_batch_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.student_batch_batch_id_seq', 75, true);


--
-- Name: time_slot_slot_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.time_slot_slot_id_seq', 25, true);


--
-- Name: batch_course_map batch_course_map_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.batch_course_map
    ADD CONSTRAINT batch_course_map_pkey PRIMARY KEY (batch_id, course_id);


--
-- Name: constraint_violation_log constraint_violation_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.constraint_violation_log
    ADD CONSTRAINT constraint_violation_log_pkey PRIMARY KEY (violation_id);


--
-- Name: course course_course_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.course
    ADD CONSTRAINT course_course_code_key UNIQUE (course_code);


--
-- Name: course course_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.course
    ADD CONSTRAINT course_pkey PRIMARY KEY (course_id);


--
-- Name: faculty_course_map faculty_course_map_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.faculty_course_map
    ADD CONSTRAINT faculty_course_map_pkey PRIMARY KEY (assignment_id);


--
-- Name: faculty faculty_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.faculty
    ADD CONSTRAINT faculty_email_key UNIQUE (email);


--
-- Name: faculty faculty_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.faculty
    ADD CONSTRAINT faculty_pkey PRIMARY KEY (faculty_id);


--
-- Name: faculty faculty_short_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.faculty
    ADD CONSTRAINT faculty_short_name_key UNIQUE (short_name);


--
-- Name: master_timetable master_timetable_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.master_timetable
    ADD CONSTRAINT master_timetable_pkey PRIMARY KEY (timetable_id);


--
-- Name: room room_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.room
    ADD CONSTRAINT room_pkey PRIMARY KEY (room_id);


--
-- Name: room room_room_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.room
    ADD CONSTRAINT room_room_number_key UNIQUE (room_number);


--
-- Name: scheduling_constraint scheduling_constraint_constraint_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scheduling_constraint
    ADD CONSTRAINT scheduling_constraint_constraint_name_key UNIQUE (constraint_name);


--
-- Name: scheduling_constraint scheduling_constraint_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scheduling_constraint
    ADD CONSTRAINT scheduling_constraint_pkey PRIMARY KEY (constraint_id);


--
-- Name: student_batch student_batch_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_batch
    ADD CONSTRAINT student_batch_pkey PRIMARY KEY (batch_id);


--
-- Name: time_slot time_slot_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.time_slot
    ADD CONSTRAINT time_slot_pkey PRIMARY KEY (slot_id);


--
-- Name: master_timetable uq_assignment_slot; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.master_timetable
    ADD CONSTRAINT uq_assignment_slot UNIQUE (assignment_id, slot_id);


--
-- Name: student_batch uq_batch_identity; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_batch
    ADD CONSTRAINT uq_batch_identity UNIQUE (sub_batch, section);


--
-- Name: time_slot uq_day_time; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.time_slot
    ADD CONSTRAINT uq_day_time UNIQUE (day_of_week, start_time);


--
-- Name: faculty_course_map uq_faculty_course; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.faculty_course_map
    ADD CONSTRAINT uq_faculty_course UNIQUE (faculty_id, course_id);


--
-- Name: idx_batch_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_batch_identity ON public.student_batch USING btree (sub_batch, section);


--
-- Name: idx_course_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_course_code ON public.course USING btree (course_code);


--
-- Name: idx_faculty_short_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_faculty_short_name ON public.faculty USING btree (short_name);


--
-- Name: idx_room_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_room_number ON public.room USING btree (room_number);


--
-- Name: idx_slot_group; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_slot_group ON public.time_slot USING btree (slot_group);


--
-- Name: idx_timetable_slot; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_timetable_slot ON public.master_timetable USING btree (slot_id);


--
-- Name: idx_violation_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_violation_time ON public.constraint_violation_log USING btree (detected_at DESC);


--
-- Name: batch_course_map batch_course_map_batch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.batch_course_map
    ADD CONSTRAINT batch_course_map_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.student_batch(batch_id) ON DELETE CASCADE;


--
-- Name: batch_course_map batch_course_map_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.batch_course_map
    ADD CONSTRAINT batch_course_map_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.course(course_id) ON DELETE CASCADE;


--
-- Name: constraint_violation_log constraint_violation_log_constraint_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.constraint_violation_log
    ADD CONSTRAINT constraint_violation_log_constraint_id_fkey FOREIGN KEY (constraint_id) REFERENCES public.scheduling_constraint(constraint_id) ON DELETE SET NULL;


--
-- Name: constraint_violation_log constraint_violation_log_timetable_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.constraint_violation_log
    ADD CONSTRAINT constraint_violation_log_timetable_id_fkey FOREIGN KEY (timetable_id) REFERENCES public.master_timetable(timetable_id) ON DELETE SET NULL;


--
-- Name: faculty_course_map faculty_course_map_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.faculty_course_map
    ADD CONSTRAINT faculty_course_map_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.course(course_id) ON DELETE CASCADE;


--
-- Name: faculty_course_map faculty_course_map_faculty_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.faculty_course_map
    ADD CONSTRAINT faculty_course_map_faculty_id_fkey FOREIGN KEY (faculty_id) REFERENCES public.faculty(faculty_id) ON DELETE CASCADE;


--
-- Name: master_timetable master_timetable_assignment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.master_timetable
    ADD CONSTRAINT master_timetable_assignment_id_fkey FOREIGN KEY (assignment_id) REFERENCES public.faculty_course_map(assignment_id) ON DELETE CASCADE;


--
-- Name: master_timetable master_timetable_batch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.master_timetable
    ADD CONSTRAINT master_timetable_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.student_batch(batch_id) ON DELETE CASCADE;


--
-- Name: master_timetable master_timetable_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.master_timetable
    ADD CONSTRAINT master_timetable_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.room(room_id) ON DELETE SET NULL;


--
-- Name: master_timetable master_timetable_slot_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.master_timetable
    ADD CONSTRAINT master_timetable_slot_id_fkey FOREIGN KEY (slot_id) REFERENCES public.time_slot(slot_id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict noCiqgKGtxETYcYbvpl0hsez5qKB2vcRHeF5OVgjzybmWRb5lsrMyxLVqaCqiqK

