#import "@preview/faithful-acmart:0.1.0": *

// Replace the sample authors and publication metadata with your paper's details.
#show: acmart.with(
  format: "acmsmall",
  title: "Scheduling with dependency graphs",
  journal: "JACM",
  acm-volume: 1,
  acm-number: 1,
  acm-article: 1,
  acm-year: 2026,
  acm-month: 7,
  doi: "10.1145/nnnnnnn.nnnnnnn",
  copyright: "acmlicensed",
  authors: (
    (
      name: "Ada Lovelace",
      note: [Both authors contributed equally.],
      email: "ada@example.org",
    ),
    (
      name: "Charles Babbage",
      note: [Both authors contributed equally.],
      corresponding: true,
      email: "charles@example.org",
      affiliation: (
        institution: "Analytical Engine Institute",
        city: "London",
        country: "UK",
      ),
    ),
  ),
  abstract: [
    A task can begin only after its prerequisites have finished.
    We represent these dependencies as a directed graph and use topological sorting to construct a valid task order.
    A four-task example illustrates why several orders can satisfy the same constraints and how a cycle prevents completion.
  ],
  ccs: ((500, "Mathematics of computing", "Graph algorithms"),),
  keywords: ("scheduling", "dependency graphs", "topological sorting"),
)

= Dependencies and task order

A data-processing workflow may collect records, clean them, validate their schema, and analyze the result.
Some tasks must follow others, while independent tasks can run in either order.
A dependency graph records these constraints without choosing a complete schedule.

Let $G = (V, E)$ be a finite directed graph.
Each vertex is a task, and an edge $(u, v) in E$ means that $u$ must finish before $v$ begins.
Topological sorting constructs an order that respects every edge @Kahn1962.

#definition[
  A _topological ordering_ of $G$ is a sequence containing every vertex exactly once, with $u$ before $v$ whenever $(u, v) in E$.
]

== A four-task workflow

In @workflow, collection precedes both cleaning and validation.
Analysis requires both of those tasks to finish.
Cleaning and validation can therefore exchange places in a sequential schedule.

#figure(
  {
    let task(name) = box(width: 65pt, inset: 6pt, stroke: 0.5pt, radius: 2pt, name)
    grid(
      columns: (auto, 24pt, auto, 24pt, auto),
      row-gutter: 10pt,
      align: center + horizon,
      grid.cell(rowspan: 2, task[Collect]), [↗], task[Clean], [↘],
      grid.cell(rowspan: 2, task[Analyze]),
      [↘], task[Validate], [↗],
    )
  },
  placement: none,
  caption: [A dependency graph with two valid task orders.],
) <workflow>

= Constructing an order

#theorem(name: "Topological ordering")[
  Every finite directed acyclic graph has a topological ordering.
] <topological-order>

#proof[
  The empty graph has an empty ordering.
  A nonempty finite acyclic graph has a vertex with no incoming edges: otherwise, repeatedly following incoming edges would eventually revisit a vertex and form a cycle.
  Remove a vertex with no incoming edges, order the remaining graph by induction, and put the removed vertex first.
]

The proof of @topological-order gives a construction based on repeatedly removing a ready task.
A task is _ready_ when all its predecessors have finished.
An implementation can maintain an incoming-edge count for each vertex, following the approach of #cite-text(<Kahn1962>):

+ Count the incoming edges of each vertex and collect the vertices whose count is zero.
+ Remove a ready vertex, append it to the order, and decrease the count of each successor.
+ Add any newly ready vertices and repeat until no ready vertex remains.

With adjacency lists and a queue of ready vertices, each vertex enters the queue once and each edge causes one decrement.
The running time is therefore $O(abs(V) + abs(E))$.

== Checking the result

@orders lists the complete set of valid orders for @workflow.
Both place collection first and analysis last.

#figure(
  tabular(
    columns: 5,
    toprule(),
    [Order], [First], [Second], [Third], [Fourth],
    midrule(),
    [1], [Collect], [Clean], [Validate], [Analyze],
    [2], [Collect], [Validate], [Clean], [Analyze],
    bottomrule(),
  ),
  placement: none,
  caption: [Valid sequential orders for the four-task workflow.],
) <orders>

The algorithm has two possible outcomes:

- Every task appears in the output, giving a valid order.
- Tasks remain but none is ready, indicating a cycle among the remaining tasks.

=== Cyclic dependencies
Adding an edge from analysis back to collection creates a cycle and leaves no task ready at the start.
Strongly connected components can help identify the tasks involved in cyclic dependencies @Tarjan1972.

= Conclusion

A dependency graph separates precedence constraints from the choice of a schedule.
For an acyclic graph, topological sorting produces a valid order in linear time.
Task durations and resource limits require additional scheduling decisions beyond the order alone.

#bibliography("refs.bib")
