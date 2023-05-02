declare namespace aeet = "http://aeet.korpora.org";
declare default element namespace "http://www.tei-c.org/ns/1.0";
declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace telota = "http://www.telota.de";
declare variable $entries external;
declare variable $ediarum-index-id external;

(: copy element and wrap in <original> :)
declare function aeet:copy-original($node) {
    element original {
        aeet:strip-unnecessary-namespaces(copy-of($node))
    }
};

(: strip unnecessary namespace nodes, see https://stackoverflow.com/questions/23002655/xquery-how-to-remove-unused-namespace-in-xml-node :)
declare function aeet:strip-unnecessary-namespaces($n as node()) as node() {
    if($n instance of element()) then (
        element { node-name($n) } {
            $n/@*,
            $n/node()/aeet:strip-unnecessary-namespaces(.)
        }
    ) else if($n instance of document-node()) then (
        document { aeet:strip-unnecessary-namespaces($n/node()) }
    ) else (
        $n
    )
};

(: from Ediarum's config.xqm, slightly tweaked :)
declare function aeet:get-ediarum-index-without-params($entries, $ediarum-index-id, $show-details, $order) {
    switch($ediarum-index-id)
    case "persons" return (
        let $ul :=
            element ul {
                for $x in $entries//tei:person
                let $name :=
                    if ($x/tei:persName[@type='reg'][1]/tei:forename)
                    then (concat(normalize-space(string-join($x/tei:persName[@type='reg'][1]/tei:surname/text())), ', ', normalize-space(string-join($x/tei:persName[@type='reg'][1]/tei:forename//text()))))
                    else (normalize-space(string-join($x/tei:persName[@type='reg'][1]/tei:name[1]/text())))
                let $lifedate :=
                    if ($x/tei:floruit)
                    then (concat(' (', $x/tei:floruit, ')'))
                    else if ($x/tei:birth)
                        then (concat(' (', $x/tei:birth[1], '-', $x/tei:death[1], ')'))
                        else ()
                let $note :=
                    if ($x/tei:note//text() and $show-details='note')
                    then (concat(' (', normalize-space(string-join($x/tei:note//text())), ')'))
                    else ()
                order by if ($order) then $name else ()
                return
                    try {
                        element li {
                            attribute xml:id { $x/@xml:id},
                            element span {
                                concat($name, $lifedate, $note)
                            },
                            aeet:copy-original($x)
                        }
                    } catch * {
                        error((), "Error in file: "||document-uri(root($x))||" in entry: "||serialize($x))
                    }
            }
        return
        $ul
    )
    case "places" return (
        let $ul :=
            element ul {
                for $place in $entries//tei:place
                let $name :=
                    if ($place[ancestor::tei:place])
                    then (normalize-space(string-join($place/ancestor::tei:place/tei:placeName[@type='reg'][1]/text()))||' - '||normalize-space(string-join($place/tei:placeName[@type='reg'][1]/text())))
                    else (normalize-space(string-join($place/tei:placeName[@type='reg'][1]/text())))
                let $altname :=
                    if ($place/tei:placeName[@type='alt'] and $show-details='altname')
                    then (' ['||
                        string-join(
                            for $altname at $pos in $place/tei:placeName[@type='alt']
                            return
                            if ($pos=1)
                            then (normalize-space(string-join($altname/text())))
                            else (', '||normalize-space(string-join($altname/text())))
                        )
                    ||']')
                    else ()
                let $note :=
                    if ($place/tei:note//text() and $show-details='note')
                    then (concat(' (', normalize-space(string-join($place/tei:note[1]//text())), ')'))
                    else ()
                order by if ($order) then $name[1] else ()
                return
                    try {
                        element li {
                            attribute xml:id { $place/@xml:id},
                            element span {
                                ($name||$altname||$note)
                            },
                            aeet:copy-original($place)
                        }
                    } catch * {
                        error((), "Error in file: "||document-uri(root($place))||" in entry: "||serialize($place))
                    }
            }
        return
            $ul
    )
    case "items" return (
        let $ul :=
            element ul {
                for $item in $entries//tei:item
                let $name :=
                    if ($item[ancestor::tei:item])
                    then (normalize-space(string-join($item/ancestor::tei:item/tei:label[@type='reg'][1]/text()))||' - '||normalize-space(string-join($item/tei:label[@type='reg'][1]/text())))
                    else (normalize-space(string-join($item/tei:label[@type='reg'][1]/text())))
                order by if ($order) then $name[1] else ()
                return
                try {
                    element li {
                        attribute xml:id {$item/@xml:id},
                        element span {
                            $name
                        },
                        aeet:copy-original($item)
                    }
                } catch * {
                    error((), "Error in file: "||document-uri(root($item))||" in entry: "||serialize($item))
                }
            }
        return
            $ul
    )
    case "organisations" return (
        let $ul :=
            element ul {
                for $org in $entries//tei:org
                let $name := normalize-space(string-join($org/tei:orgName[@type='reg'][1]/text()))
                order by if ($order) then $name[1] else ()
                return
                    try {
                        element li {
                            attribute xml:id { $org/@xml:id},
                            element span {
                                $name
                            },
                            aeet:copy-original($org)
                        }
                    } catch * {
                        error((), "Error in file: "||document-uri(root($org))||" in entry: "||serialize($org))
                    }
            }
        return
            $ul
    )
    case "bibliography" return (
        let $ul :=
            element ul {
                for $x in $entries//tei:bibl
                let $author :=
                    if ($x/tei:author[1]/tei:persName[1]/tei:surname/normalize-space())
                    then (concat(normalize-space(string-join($x/tei:author[1]/tei:persName[1]/tei:surname/text())), ', '))
                    else ()
                let $title := normalize-space(string-join($x/tei:title/text()))
                order by $author, $title
                return
                    try {
                        element li {
                            attribute xml:id { $x/@xml:id},
                            element span {
                                concat($author, $title)
                            },
                            aeet:copy-original($x)
                        }
                    } catch * {
                        error((), "Error in file: "||document-uri(root($x))||" in entry: "||serialize($x))
                    }
            }
        return
            $ul
    )
    (:
    case "letters" return (
        let $ul :=
            element ul {
                for $x in collection($data-collection)//tei:TEI[.//tei:correspAction]
                let $title := normalize-space(string-join($x//tei:titleStmt/tei:title/text()))
                order by $x//tei:correspAction[@type='sent']/tei:date/(@when|@from|@notBefore)/data(.)
                return
                    try {
                        element li {
                            attribute xml:id { $x/@xml:id/data(.)},
                            element span {
                                $title
                            }
                        }
                    } catch * {
                        error((), "Error in file: "||document-uri(root($x))||" in entry: "||serialize($x))
                    }
            }
        return
            $ul
    )
    case "comments" return (
        let $ul :=
            element ul {
                for $x in collection($data-collection)//tei:TEI
                let $fileName := substring-after(base-uri($x), 'data/')
                order by $fileName
                return
                    for $note in $x//tei:seg/tei:note
                    return
                        try {
                            element li {
                                attribute id { $x/@xml:id/data(.)||'/#'||$note/@xml:id/data(.)},
                                element span {
                                    $fileName||' - '||substring($note//normalize-space(), 0, 100)
                                }
                            }
                        } catch * {
                            error((), "Error in file: "||document-uri(root($x))||" in entry: "||serialize($x))
                        }
            }
        return
            $ul
    )
    :)
    default return
        ()
};
let $show-details := true()
let $order := true()
return aeet:get-ediarum-index-without-params($entries, $ediarum-index-id, $show-details, $order)