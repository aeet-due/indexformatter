declare namespace aeet = "http://aeet.korpora.org";
(: declare default element namespace "http://www.tei-c.org/ns/1.0"; :)
declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace telota = "http://www.telota.de";
declare variable $entries external;
declare variable $copy-original as xs:boolean external;
declare variable $ediarum-index-id-override external;

(: copy element and wrap in <original> :)
declare function aeet:copy-original($node) {
    if ($copy-original) then
        aeet:strip-unnecessary-namespaces(<tei:original>
            {copy-of($node)}
        </tei:original>)
    else ()
};

(:
    strip unnecessary namespace nodes by rebuilding,
    see https://stackoverflow.com/questions/23002655/xquery-how-to-remove-unused-namespace-in-xml-node
:)
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

(: remove empty strings from sequence :)
declare function aeet:non-empty-strings($sequence){
    for $item in $sequence
    where $item != ""
    return $item
};

(: guess type of list based on contained list elements :)
declare function aeet:determine-type($entries) {
    if ($entries//tei:body/tei:listPerson) then "persons"
    else if ($entries//tei:body/tei:listPlace) then "places"
    else if ($entries//tei:body/tei:listOrg) then "organizations"
    else if ($entries//tei:body/tei:listBibl) then "bibliography"
    else if ($entries//tei:body/tei:list) then "items"
    else error((), "Could not guess index type")
};

declare function aeet:format-surname($name){
    let $surname := string-join($name/tei:surname[not(@type) or @type != 'birth'], " "),
        $birthSurname := string-join($name/tei:surname[@type = 'birth'], " ")
    return normalize-space(string-join(
    ($surname, if ($birthSurname) then "geb. " || $birthSurname else ()), " "))
};

declare function aeet:parenthesize($sequence){
    let $effective-sequence := aeet:non-empty-strings($sequence)
    return if (not(empty($effective-sequence))) then
        ("(" || string-join($effective-sequence, ", ") || ")")
        else ()
};

(: from Ediarum's config.xqm, slightly tweaked :)
declare function aeet:get-ediarum-index-without-params($entries, $ediarum-index-id, $show-details, $order) {
    switch($ediarum-index-id)
    case "persons" return (
        let $ul :=
            element ul {
                for $x in $entries//tei:person
                let $name :=
                    if ($x/tei:persName[@type='reg'][1])
                    then
                        let $surname := aeet:format-surname($x/tei:persName[@type='reg'][1]),
                            $forename := normalize-space(string-join($x/tei:persName[@type='reg'][1]/tei:forename, " ")),
                            $effectiveForename := if ($forename = '' ) then  "(OHNE VORNAME)" else $forename,
                            $effectiveSurname := if ($surname = '' ) then "(OHNE NACHNAME)" else $surname
                        return normalize-space(string-join((
                            $effectiveSurname,
                            $effectiveForename),  ', '))
                    else (normalize-space(string-join($x/tei:persName[@type='reg'][1]/tei:name[1]))),
                    $orderName :=replace($name, "v(\.|[ao][mn])(\sd(e[rmn]|\.))?\s+|d[ue](l(l[oa])?)?('|\s)+", ""),
                    $lifeDate := if ($x/tei:floruit)
                        then (concat(' (', $x/tei:floruit, ')
                        '))
                        else if ($x/tei:birth)
                            then (concat(' (', $x/tei:birth[1], '–', $x/tei:death[1], ')'))
                            else (),
                        $note := (
                            if ($x/tei:name[@type='alias']) then concat("[auch: ", string-join($x/name[@type='alias']) , "]") else (),
                            if ($x/tei:name[@type='occursAs']) then concat("[oder: ", string-join($x/name[@type='occursAs']) , "]") else (),
                            if ($x/tei:note//text() and $show-details='note')
                                then (concat(' (', normalize-space(string-join($x/tei:note)), ')'))
                                else ()
                        )
                order by if ($order) then $orderName else ()
                return
                    try {
                        element li {
                            attribute xml:id { $x/@xml:id},
                            element span {
                                concat($name, $lifeDate, $note)
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
                    then (normalize-space(string-join($place/ancestor::tei:place/tei:placeName[@type='reg'][1]/text()))||' - '||normalize-space(string-join($place/tei:placeName[@type='reg'][1])))
                    else (normalize-space(string-join($place/tei:placeName[@type='reg'][1]))),
                    $altname :=
                    if ($place/tei:placeName[@type='alt'] and $show-details='altname')
                    then (' [' ||
                        string-join(
                            for $altname at $pos in $place/tei:placeName[@type='alt']
                            return
                            if ($pos=1)
                            then (normalize-space(string-join($altname)))
                            else (', ' || normalize-space(string-join($altname)))
                        )
                    ||']')
                    else (),
                    $note :=
                    if ($place/tei:note and $show-details='note')
                    then normalize-space($place/tei:note[1])
                    else (),
                    $additionalInfo := (string-join(aeet:non-empty-strings(($place/tei:region[@type="county"], $place/tei:region[@type="state"], $place/tei:country)), ", "))

                order by if ($order) then $name[1] else ()
                return
                    try {
                        element li {
                            attribute xml:id { $place/@xml:id},
                            element span {
                                string-join(($name, $altname, aeet:parenthesize(($note, $additionalInfo))), " ")
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
                    else (),
                    $title := normalize-space(string-join($x/tei:title/text()))
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
let $show-details := ('note', 'altname')
let $order := true()
let $ediarum-index-id := if ($ediarum-index-id-override = "guess") then aeet:determine-type($entries) else $ediarum-index-id-override
return aeet:get-ediarum-index-without-params($entries, $ediarum-index-id, $show-details, $order)