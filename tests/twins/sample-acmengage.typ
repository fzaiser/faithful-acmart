// sample-acmengage — port of the upstream acmart sample (acmart/samples,
// acmengage.dtx). ACM EngageCSEdu course-material format: two-column, Synopsis
// instead of Abstract, CC license, engage metadata (\setengagemetadata not
// modelled — metadata key/value pairs appear before Synopsis in LaTeX but are
// omitted here; keyword/body structure otherwise matches.
// Diffed against out/latex/acmengage.pdf.
#import "/src/lib.typ": acmart

#show: acmart.with(
  format: "acmengage",
  title: "EngageCSEdu Submission Title (600 char limit)",
  booktitle: "ACM EngageCSEdu",
  acm-year: 2022, acm-month: 5,
  doi: "XXXXXXX.XXXXXXX",
  copyright: "cc", cc-type: "by",
  authors: (
    (name: "Author One",
     email: "author1@institution.edu",
     affiliation: (institution: "University of XXX",
                   city: "SomeCity", country: "SomeCountry")),
    (name: "Author Two",
     email: "author2@institution.xxx",
     affiliation: (institution: "Some School",
                   city: "SomeCity", country: "SomeCountry")),
    (name: "Author Three",
     email: "author3@school.xxx",
     affiliation: (institution: "A3 affiliation",
                   city: "SomeCity", country: "SomeCountry")),
  ),
  abstract: [
    A required section. The synopsis is similar to a paper abstract. The synopsis
    will display in the digital library as the abstract. The synopsis should be
    copied into ScholarOne as the abstract for submission. The synopsis should
    contain an overall description of the Open Educational Resource (OER). The
    synopsis lets other instructors quickly understand what this material is about.
    Include any learning objectives and a description of the approach taken. Put
    details about implementation and necessary prerequisite knowledge in the
    Recommendations section. The following template is a suggested format: This
    [assignment/project/homework/lab] helps students gain experience and proficiency
    with [e.g. arrays, for/while loops, conditional statements.] Students will learn
    how to [skills acquired]. The reader should get an understanding of what topic
    is associated with the OER and what, if anything, the students will be asked to
    do.
  ],
  keywords: ("Arithmetic Operators", "Assignment Statements", "Comprehension",
             "Student Voice"),
)

= Engagement Highlights

A required section. This section of the paper should detail how the OER engages the
students. The engagement must be based on at least one evidenced-based teaching
practice known to broaden participation or improve student learning. Examples include
the practices from the NCWIT Engagement Practices Framework: using meaningful and
relevant content, making interdisciplinary connections to CS, addressing
misconceptions about the field of CS, incorporating student choice, giving effective
encouragement, mitigating stereotype threat, offering student-centered assessments,
providing opportunities for interaction with faculty, avoiding stereotypes, using
well-structured collaborative learning, or encouraging student interaction. Other
potential evidence-based practices include using culturally relevant pedagogy, or
universal design for learning. All submissions must identify what evidence-based
practice they incorporate and be specific in how the practice is included within the
OER.

Information on how to differentiate this assignment (i.e. provide different versions
for students of differing abilities) could also go in this section. It could also
outline how instructors might modify the assignment to increase enhance student
engagement. If these modifications are extensive, they could also be discussed in
their own section.

= Recommendations

A required section. In this section authors should give specific recommendations and
advice to other instructors who might want to adapt this resource for their own
classroom. Important information to include in this section includes identifying how
much time is required to introduce or complete the task, potential pitfalls or
student struggles, lessons learned from using the OER, and any information on
extensions or differentiation for students. Think of this section as the information
you would provide a colleague before they use this OER in their classroom.

= Additional Sections

Optional. Authors may add additional sections to fully explain all the pieces of
their OER. It can (and probably should) have multiple sections and the section
headers are at the discretion of the authors. Sections may expand on information
presented in the synopsis, recommendations, and engagement highlights. Suggested
sections include: Introduction, Background Material, Implementation Guidelines,
Marking Guidelines, Extensions and Modifications, Pitfalls, Acknowledgements,
Student Feedback, and References.

= Related Online Resources

EngageCSEdu requires that all materials that are part of the OER submission be
included with the submission and not just URL links to materials stored on other
sites. However, any related background or reference material used to provide
instructor or student knowledge as opposed to instructional material may be included
as citations within the paper (see @sec:citations) or you may include a numbered
list of external links and extensions in an optional section titled "Auxilary
Materials" that should come immediately before "References".

= Materials

A required section. You must provide a list of the contents of the zipped file
including a description of each contained file. This may be provided as text or as
an unordered list.

A single zipped file containing all the OER instructional materials including
assignment handouts / specification, starter code, rubric, solution, etc. will also
be submitted.

= Meta-Data

This section is included in the template to explain the choices for the meta-data at
the top of the paper. It should not be included in the final paper submission.

== Course

Current courses are:

- CS0---a breadth first introductory computing course similar to Exploring Computer
  Science or AP CS Principles
- CS1---an introductory programming course covering topics normally associated with
  an imperative or functional programming course. Similar to an AP CS A course
- Data Structures---a follow-on course occurring after CS1 that introduces linear
  and non-linear data structures including implementation and usage
- Discrete Math---a course covering discrete mathematical structures such as
  integers, graphs and logic statements. This may include logic, set theory,
  combinatorics, graphy theory, number theory, topology, etc.
- HCI---a course in the general area of human computer interaction. This might be a
  general HCI course or a course in a specific subdiscipline such as user-centred
  design.

More than one course may be selected. If you are submitting an OER for a special
topics issue of Engage, please discuss the appropriate course choice with the guest
editors of the special issue.

== Programming Language
Authors may select all that apply from the following list:
- C
- C++
- C\#
- Java
- JavaScript
- Processing
- Python
- Racket (DrScheme)
- Scheme
- Scratch
- Pseudocode
- Other
- None

== Resource Type
One resource type must be selected. Current list to select from includes:

- Assignment---the most common OER type. Typically represents a task assigned to
  individual or groups of students that will be completed outside of class time.
- Lecture slides---an annotated set of presentation slides to introduce or explain a
  topic, typically a cutting-edge research topic, to a more lay audience. An example
  might be explaining a specific cryptography algorithm, blockchain, or an AI / ML
  solution to a problem.
- Lab---this represents a task assigned to an individual or group of students to be
  completed under supervision, usually during a closed-lab model
- Project---an assignment that is of a longer duration, perhaps multiple weeks to an
  entire term
- Tutorial---a task usually completed by an individual to learn some material on
  their own
- Other---any other type of OER that does not fit into one of the above categories

== CS Concepts
This is selectable from the ontology of topics found at
#link("https://www.engage-csedu.org/ontology"). Up to three topics may be selected.
Eventually this page will be a tool allowing you to select up to three nodes in the
tree and then copy / paste the descriptive text into your document and the submission
system.

== Knowledge Unit
Authors will select the most appropriate one from the following list:

- Programming Concepts---anything involving programming
- Data Structures---anything involving data structures
- Software Development Methods---if the OER centers around software development
  (i.e., requirements gathering, testing, maintenance, code reviews) rather than the
  actual programming content
- Discrete Math---anything involving discrete math
- N/A---not applicable

== Creative Commons License
During the submission process on ScholarOne, authors will select one create commons
license from the following list:

- CC BY-SA
- CC BY-NC
- CC BY-NC-ND
- CC BY-NC-SA
- CC BY-ND
- CC BY

The correct typesetting of materials under creative commons license requires the
corresponding CC icon. A modern TeX distribution includes these icons in the package
_doclicense_ @doclicense. In case your distribution does not have them, ACM provides
a file `ccicons.zip` with these icons. Just unzip it in the same directory where
your document is.

More information on Creative Common Licensing may be found at
#link("https://creativecommons.org/licenses/").

= Submission
When you make a submission using ScholarOne you must upload:

- an anonymized version of this paper for review
- a zipped file containing all the student-facing materials. The materials in this
  file must also be anonymized for the purposes of fully anonymous review.

= Citations and References
<sec:citations>
We recommend using BibTeX to prepare your references. The bibliography is included in
your source document with these two commands, placed just before the
`\end{document}` command:
```
  \bibliographystyle{ACM-Reference-Format}
  \bibliography{bibfile}
```
where "`bibfile`" is the name, without the "`.bib`" suffix, of the BibTeX file.

Here are a few examples of the types of things you might cite in an EngageCSEdu
submission: a book @Kosiur01, a journal article @Abril07, an informally published
work @Harel78, an online document / world wide web resource @Thornburg01 @Ablamowicz07,
a video @Obama08, a software package @R, and an online dataset @UMassCitations.

For other examples, see the file sample-acmsmall-conf.tex @CTANacmart.

= Auxiliary Materials
This section is optional, but if included must immediately precede the References
section. If there are no References, Auxiliary Materials should be last. This should
be a numbered list of URLs with an optional brief description of the content found at
each URL. Here is an example.
+ #link("https://somenews.org/xxx/") A news article relevant to this OER.
+ #link("https://somesite.gov/xxx/") A relevant government report.
+ #link("https://someplace.edu/xxxx/") A public data set of interest.
+ #link("https://github.com/xxxx/") A public github project that is related.

#bibliography("/tests/twins/sample-base.bib")
