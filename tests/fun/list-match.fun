// [ 3 : 4 : 5 : .Vals ]

let rebuild = fun [ h : t ] -> [ h : t ]
                | x         -> [ ]
 in rebuild [ 3 : 4 : 5 : .Vals ]
