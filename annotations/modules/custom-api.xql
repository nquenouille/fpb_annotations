xquery version "3.1";

(:  @author Nadine Quenouille :)

module namespace api="http://teipublisher.com/api/custom";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace vc="http://www.w3.org/2007/XMLSchema-versioning";
import module namespace validation="http://exist-db.org/xquery/validation";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace dapi="http://teipublisher.com/api/documents" at "lib/api/document.xql";
import module namespace errors = "http://e-editiones.org/roaster/errors";
import module namespace rutil="http://e-editiones.org/roaster/util";
import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "lib/util.xql";
import module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config" at "pm-config.xql";
import module namespace nav="http://www.tei-c.org/tei-simple/navigation" at "../../navigation.xql";
import module namespace http = "http://expath.org/ns/http-client";
import module namespace router="http://e-editiones.org/roaster";

declare variable $api:NOT_FOUND := xs:QName("errors:NOT_FOUND_404");

declare function api:lookup($name as xs:string, $arity as xs:integer) {
    try {
        function-lookup(xs:QName($name), $arity)
    } catch * {
        ()
    }
};

(: Get status of availability of the document :)
declare function api:status-metadata($request as map(*)) {
    let $doc := xmldb:decode($request?parameters?path)
    let $xml := config:get-document($doc)
    return
        if (exists($xml)) then
            let $config := tpu:parse-pi(root($xml), ())
            let $attr := root($xml)//tei:teiHeader/tei:revisionDesc/@status
            return map {"content": data($attr)}
        else
            error($errors:NOT_FOUND, "Document " || $doc || " not found")
};

(:~
 : Merge and save the status, editor and date passed in the request body.
 :)
declare function api:status-save($request as map(*)) {
    let $body := $request?body
    let $header := $request?head
    let $path := xmldb:decode($request?parameters?path)
    let $srcDoc := config:get-document($path)
    let $stat := $request?parameters?status
    let $hasAccess := sm:has-access(document-uri(root($srcDoc)), "rw-")
    let $user := rutil:getDBUser()
    return
        if (not($hasAccess) and request:get-method() = 'PUT') then
            error($errors:FORBIDDEN, "Not allowed to write to " || $path)
        else if ($srcDoc) then
            let $doc := util:expand($srcDoc/*, 'add-exist-id=all')
            let $attr := $srcDoc//tei:teiHeader/tei:revisionDesc
            let $attrChange := $srcDoc//tei:teiHeader/tei:revisionDesc/tei:change
            let $status := $srcDoc//tei:teiHeader/tei:revisionDesc/@status
            let $change := $srcDoc//tei:teiHeader/tei:revisionDesc/tei:change/@who
            let $when := $srcDoc//tei:teiHeader/tei:revisionDesc/tei:change/@when
            let $date := format-date(current-date(), "[Y0001]-[M01]-[D01]")
            let $europeDate := format-date(current-date(), "[D].[M].[Y]")
            let $docMerge := 
                if (exists($attr)) then
                    if($attrChange[@when = $date and @who = $user?fullName]) then
                        if(not($status="undefined")) then
                        update value $status with $stat else
                            update value $status with "status.new"
                    else
                        update insert (<change xmlns="http://www.tei-c.org/ns/1.0" who="{$user?fullName}" when="{$date}">Annotationen gesetzt</change>) into $attr
                else 
                    update insert (
                        <revisionDesc xmlns="http://www.tei-c.org/ns/1.0" status="status.new">
                            <change xmlns="http://www.tei-c.org/ns/1.0" who="{$user?fullName}" when="{$date}">Ersterfassung von Annotationen am {$europeDate}</change>
                        </revisionDesc>) 
                        into $srcDoc//tei:teiHeader
(:            let $stored :=:)
(:                if (request:get-method() = 'PUT') then :)
(:                    xmldb:store(util:collection-name($srcDoc), util:document-name($srcDoc), $srcDoc):)
(:                else:)
(:                    ():)
            return map {
                    "content": $srcDoc}
        else
            error($errors:NOT_FOUND, "Document " || $path || " not found")
};


(: Get documents that are finished :)
declare function api:get-doc($request as map(*)) {
    let $doc := xmldb:decode($request?parameters?id)
    let $srcDoc := config:get-document($doc)
    return
        if ($doc) then
            let $path := xmldb:encode-uri($config:data-root || "/" || $doc)
            let $filename := replace($doc, "^.*/([^/]+)$", "$1")
            let $mime := ($request?parameters?type, xmldb:get-mime-type($path))[1]
            let $src := util:expand($srcDoc/*, 'add-exist-id=all')
            let $attr := $src//tei:teiHeader/tei:revisionDesc[@status="status.final"]
            return
                if (util:binary-doc-available($path) and $attr) then
                    response:stream-binary(util:binary-doc($path), $mime, $filename)
                else if (doc-available($path) and $attr) then
                    router:response(200, $mime, doc($path))
                else
                    error($errors:NOT_FOUND, "Document " || $doc || " not found")
        else
            error($errors:BAD_REQUEST, "No document specified")
};

(: Check which documents have status='status.final' and have been modified after a given date (input), and show name, description and status :)

declare function api:list-finished-documents($request as map(*)) {
    array {
        for $html in collection($config:app-root || "/data/annotate")/*
        let $description := $html//tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title/string()
        let $status := $html//tei:teiHeader/tei:revisionDesc/@status/string()
        let $path := $config:app-root || "/data/annotate/" || util:document-name($html)
        let $lmdate := xmldb:last-modified(util:collection-name($html), util:document-name($html)) cast as xs:string
        return
            if($status = "status.final" and ($lmdate > $request?parameters?date)) then
            map {
                "name": util:document-name($html),
                "path": $path,
                "title": $description,
                "status": $status,
                "lastModified": xs:date(xmldb:last-modified(util:collection-name($html), util:document-name($html))) 
            }
            else
            ()
    }
};

(: Get documents that are finished and store them into the edition's app. CAVEAT: If name of the edition's app changes, change it here, too! :)
declare function api:save-doc($request as map(*)) {
    let $doc := xmldb:decode($request?parameters?id)
    let $srcDoc := config:get-document($doc)
    return
        if ($doc) then
            let $path := xmldb:encode-uri($config:data-root || "/" || $doc)
            let $storepath := xmldb:encode-uri("../db/apps/bach-letters/data/")
            let $filename := replace($doc, "^.*/([^/]+)$", "$1")
            let $mime := ($request?parameters?type, xmldb:get-mime-type($path))[1]
            let $src := util:expand($srcDoc/*, 'add-exist-id=all')
            let $attr := $src//tei:teiHeader/tei:revisionDesc[@status="status.final"]
            let $stored := xmldb:store($storepath, $request?parameters?id, $srcDoc, "text/xml")
            return
                if (util:binary-doc-available($path) and $attr) then
                    response:stream-binary(util:binary-doc($path), $mime, $filename)
                else if (doc-available($path) and $attr) then
                    router:response(200, $mime, doc($path))
                else
                    error($errors:NOT_FOUND, "Document " || $doc || " not found")
        else
            error($errors:BAD_REQUEST, "No document specified")
};

(:  Transform document to valid TEI, check, if document is valid and copies finished document from annotate collection to BachLetters collection. CAVEAT: If name of the edition's app changes, change it here, too! :)
declare function api:copy-doc($request as map(*)) {
    let $schema-uri := doc("https://www.tei-c.org/release/xml/tei/custom/schema/relaxng/tei_all.rng")
    let $path := xmldb:decode($request?parameters?id)
    let $doc := replace($request?parameters?id, "annotate/", "")
    let $docx := doc(xmldb:encode-uri($config:data-root || "/" || $path))
    let $srcDoc := config:get-document($path)
    let $sourceURI := xmldb:encode-uri($config:app-root || "/data/annotate/")
    let $targetURI := xmldb:encode-uri("/db/apps/bach-letters/data/")
    let $preserve := "true"
    let $src := util:expand($srcDoc/*, 'add-exist-id=all')
    let $attr := $src//tei:teiHeader/tei:revisionDesc[@status="status.final"]
    let $clear := validation:clear-grammar-cache()
    let $report := validation:jing-report($docx, $schema-uri)
    let $validation := if(validation:jaxv($docx, $schema-uri) or validation:jing($docx, $schema-uri) = true()) then "valid" else "false"
    let $post := api:setTags($request)
    return 
        if($attr and $validation="valid") then
            ("Dokument erfolgreich kopiert nach ", xmldb:copy-resource($sourceURI, $doc, $targetURI, $doc, $preserve))
        else if (($attr and $validation="false")) then
                (codepoints-to-string(13), "The document is NOT valid TEI !!!", codepoints-to-string((10, 13)),
                for $message in $report/message[@level = "Error"]
                group by $line := $message/@line
                order by $message/@line
                return
                    ("Line ",$message/@line, ", Col. ", $message/@column, ": ", 
                        $message/text(), codepoints-to-string((10, 13))
                    ))
        else 
            ("The document's status is NOT set to 'DONE' !!!")
};

(: Add numbers to anchors and notes as well as xml:id to anchor and target attr to note :)
declare %private function api:transformNotes($nodes as node()*) {
    for $node in $nodes
    return
        typeswitch($node)
        case document-node() return 
            api:transformNotes($node/node())
        case element(tei:anchor) return
                let $num := count($node/preceding::tei:anchor[@type='anchor']) 
                let $n := update value $node[@type='anchor']/@n with $num+1
                let $target := update value $node[@type='anchor']/@xml:id with concat('n-', $num+1)
                return
                    ()
        case element(tei:note) return
            let $number := count($node/preceding::tei:note[@type='note'])
            let $n := update value $node[@type="note"]/@n with $number+1
            let $target := update value $node[@type="note"]/@target with concat('#n-', $number+1)
            return
                ()
        case element() return 
            element {node-name($node)} {
                $node/@*, 
                api:transformNotes($node/node())
            }
        default return ()
};

(: Replace notes with anchors and put notes into the "commentary" div :)
declare function api:setNotes($request as map(*)) {
    let $doc := xmldb:decode($request?parameters?path)
    let $srcDoc := config:get-document($doc)
    let $src := util:expand($srcDoc/*, 'add-exist-id=all')
    let $notes := $srcDoc//*/tei:text/tei:body/tei:div[@type='original' or @type='marginalia']//tei:note[@type="note"]
    let $notes_front := $srcDoc//*/tei:text/tei:front/tei:div[@type='original_front' or @type='marginalia_front']//tei:note[@type="note"]
    let $notes_back := $srcDoc//*/tei:text/tei:back/tei:div[@type='original_back' or @type='marginalia_back']//tei:note[@type="note"]
    let $hasAccess := sm:has-access(document-uri(root($srcDoc)), "rw-")
    return
        if (not($hasAccess) and request:get-method() = 'PUT') then
            error($errors:FORBIDDEN, "Not allowed to write to " || $doc)
        else if($srcDoc and $notes) then 
            for $note in $notes 
            let $putAnchor := update insert <anchor xmlns="http://www.tei-c.org/ns/1.0" type="anchor" xml:id="" n="" /> following $note[@type="note"][@n=""]
            let $numeroAnchor := api:transformNotes($srcDoc//*/tei:text/tei:body/tei:div[@type='original' or @type='marginalia']//*/tei:anchor[@type='anchor'])
            let $numeroNotes := update value $note[@type="note"]/@n with $note/following::tei:anchor[@type='anchor']/@n
            let $targetNotes := update value $note[@type="note"]/@target with (concat('#n-', $note/@n))
            let $notenumber := $note[@type="note"]/@n
            let $notetext := 
                if ($srcDoc//tei:text/tei:body/tei:div[@type='commentary']/tei:p/tei:note[@type="note"][@n = $notenumber]) then 
                        update insert $note preceding $srcDoc//tei:text/tei:body/tei:div[@type='commentary']/tei:p/tei:note[@n= $notenumber]
                    else if
                        ($srcDoc//tei:text/tei:body/tei:div[@type='commentary']/tei:p/tei:note[@type="note"][@n = $notenumber -1]) then 
                        update insert $note following $srcDoc//tei:text/tei:body/tei:div[@type='commentary']/tei:p/tei:note[@n= ($notenumber -1)] 
                    else if 
                        ($srcDoc//tei:text/tei:body/tei:div[@type='commentary']/tei:p/tei:note[@type="note"][@n = max($notenumber)]) then 
                        update insert $note following $srcDoc//tei:text/tei:body/tei:div[@type='commentary']/tei:p/tei:note[@n= max($notenumber)] 
                    else if
                        ($srcDoc//tei:text/tei:body/tei:div[@type='commentary']/tei:p/tei:note[@type="note"][@n = $notenumber +1]) then 
                        update insert $note preceding $srcDoc//tei:text/tei:body/tei:div[@type='commentary']/tei:p/tei:note[@n= $notenumber +1]
                    else 
                        update insert $note into $srcDoc//tei:text/tei:body/tei:div[@type='commentary']/tei:p
            let $delNotes := update delete $srcDoc//tei:text/tei:body/tei:div[@type='original' or @type='marginalia']//$note
            let $newNotes := $srcDoc//*/tei:text/tei:body/tei:div[@type='commentary']/tei:p/*
            let $countNewNotes := api:transformNotes($srcDoc)
                return map {
                    "content": $srcDoc}
        else if($srcDoc and $notes_front) then 
            for $note in $notes_front 
            let $putAnchor := update insert <anchor xmlns="http://www.tei-c.org/ns/1.0" type="anchor" xml:id="" n="" /> following $note[@type="note"][@n=""]
            let $numeroAnchor := api:transformNotes($srcDoc//*/tei:text/tei:front/tei:div[@type='original_front' or @type='marginalia_front']//*/tei:anchor[@type='anchor'])
            let $numeroNotes := update value $note[@type="note"]/@n with $note/following::tei:anchor[@type='anchor']/@n
            let $targetNotes := update value $note[@type="note"]/@target with (concat('#n-', $note/@n))
            let $notenumber := $note[@type="note"]/@n
            let $notetext := 
                if ($srcDoc//tei:text/tei:front/tei:div[@type='commentary_front']/tei:p/tei:note[@type="note"][@n = $notenumber]) then 
                        update insert $note preceding $srcDoc//tei:text/tei:front/tei:div[@type='commentary_front']/tei:p/tei:note[@n= $notenumber]
                    else if
                        ($srcDoc//tei:text/tei:front/tei:div[@type='commentary_front']/tei:p/tei:note[@type="note"][@n = $notenumber -1]) then 
                        update insert $note following $srcDoc//tei:text/tei:front/tei:div[@type='commentary_front']/tei:p/tei:note[@n= ($notenumber -1)] 
                    else if 
                        ($srcDoc//tei:text/tei:front/tei:div[@type='commentary_front']/tei:p/tei:note[@type="note"][@n = max($notenumber)]) then 
                        update insert $note following $srcDoc//tei:text/tei:front/tei:div[@type='commentary_front']/tei:p/tei:note[@n= max($notenumber)] 
                    else if
                        ($srcDoc//tei:text/tei:front/tei:div[@type='commentary_front']/tei:p/tei:note[@type="note"][@n = $notenumber +1]) then 
                        update insert $note preceding $srcDoc//tei:text/tei:front/tei:div[@type='commentary_front']/tei:p/tei:note[@n= $notenumber +1]
                    else 
                        update insert $note into $srcDoc//tei:text/tei:front/tei:div[@type='commentary_front']/tei:p
            let $delNotes := update delete $srcDoc//tei:text/tei:front/tei:div[@type='original_front' or @type='marginalia_front']//$note
            let $newNotes := $srcDoc//*/tei:text/tei:front/tei:div[@type='commentary_front']/tei:p/*
            let $countNewNotes := api:transformNotes($srcDoc)
                return map {
                    "content": $srcDoc}
        else if($srcDoc and $notes_back) then 
            for $note in $notes_back 
            let $putAnchor := update insert <anchor xmlns="http://www.tei-c.org/ns/1.0" type="anchor" xml:id="" n="" /> following $note[@type="note"][@n=""]
            let $numeroAnchor := api:transformNotes($srcDoc//*/tei:text/tei:back/tei:div[@type='original_back' or @type='marginalia_back']//*/tei:anchor[@type='anchor'])
            let $numeroNotes := update value $note[@type="note"]/@n with $note/following::tei:anchor[@type='anchor']/@n
            let $targetNotes := update value $note[@type="note"]/@target with (concat('#n-', $note/@n))
            let $notenumber := $note[@type="note"]/@n
            let $notetext := 
                if ($srcDoc//tei:text/tei:back/tei:div[@type='commentary_back']/tei:p/tei:note[@type="note"][@n = $notenumber]) then 
                        update insert $note preceding $srcDoc//tei:text/tei:back/tei:div[@type='commentary_back']/tei:p/tei:note[@n= $notenumber]
                    else if
                        ($srcDoc//tei:text/tei:back/tei:div[@type='commentary_back']/tei:p/tei:note[@type="note"][@n = $notenumber -1]) then 
                        update insert $note following $srcDoc//tei:text/tei:back/tei:div[@type='commentary_back']/tei:p/tei:note[@n= ($notenumber -1)] 
                    else if 
                        ($srcDoc//tei:text/tei:back/tei:div[@type='commentary_back']/tei:p/tei:note[@type="note"][@n = max($notenumber)]) then 
                        update insert $note following $srcDoc//tei:text/tei:back/tei:div[@type='commentary_back']/tei:p/tei:note[@n= max($notenumber)] 
                    else if
                        ($srcDoc//tei:text/tei:back/tei:div[@type='commentary_back']/tei:p/tei:note[@type="note"][@n = $notenumber +1]) then 
                        update insert $note preceding $srcDoc//tei:text/tei:back/tei:div[@type='commentary_back']/tei:p/tei:note[@n= $notenumber +1]
                    else 
                        update insert $note into $srcDoc//tei:text/tei:back/tei:div[@type='commentary_back']/tei:p
            let $delNotes := update delete $srcDoc//tei:text/tei:back/tei:div[@type='original_back' or @type='marginalia_back']//$note
            let $newNotes := $srcDoc//*/tei:text/tei:back/tei:div[@type='commentary_back']/tei:p/*
            let $countNewNotes := api:transformNotes($srcDoc)
                return map {
                    "content": $srcDoc}
        else api:transformNotes($srcDoc)
};

(: Get User and date (currently not used) :)
declare function api:getUser($request as map(*)) {
     let $userName := rutil:getDBUser()?name
     let $fullName := rutil:getDBUser()?fullName
     let $date := current-dateTime()
     return map {
         "userName": $userName,
         "fullName": $fullName,
         "date": $date
         }
};

(: Update registry, if there was an update at the source :)
declare function api:updateRegister($request as map(*)) {
    let $reg-path := "//db/apps/annotations/data/register.xml"
    let $collection := util:collection-name($reg-path)
    let $file := util:document-name($reg-path)
    let $reg-doc := doc($reg-path)
    let $persons := $reg-doc//tei:listPerson//tei:person
    let $places := $reg-doc//tei:listPlace//tei:place
    let $terms := $reg-doc//tei:listNym//tei:nym
    let $updated := ()
    let $persResults :=
        for $person in $persons
        let $id := substring-after($person/@xml:id, 'fpb-')
        let $url := "https://fpb.saw-leipzig.de/" || $id || "/json-ld/"
        let $json := try {
            json-doc($url)
        } catch * {
            ()
        }
        let $size := try {
            map:size($json) 
            } catch * { 
                () 
            } 
        let $firstname := try { $json("firstname") } catch * { () }
        let $lastname := try { $json("lastname") } catch * { () }
        let $nobility := try { $json("title_of_nobility") } catch * { () }
        
        let $json-fullname :=
            try {
            if (exists($lastname) and exists($firstname)) then
                concat($lastname, ", ", $firstname)
            else if (not(exists($lastname)) and exists($firstname) and not(exists($nobility))) then
                concat("NN, ", $firstname)
            else if (exists($lastname) and not(exists($firstname))) then
                concat($lastname, ", NN")
            else if (not(exists($lastname)) and exists($firstname) and exists($nobility)) then
                concat($firstname, ", ", $nobility)
            else
                "NN"
            } catch * { () }
        let $json-birthDate := try {$json("birthday")} catch * { () }
        let $json-birthPlace := try { $json("birthplace")?name(1)?value } catch * { () }
        let $json-birthLat := try { $json("birthplace")?latitude } catch * { () }
        let $json-birthLng := try { $json("birthplace")?longitude } catch * { () }

        let $json-deathDate := try {$json("deathday")} catch * { () }
        let $json-deathPlace := try { $json("deathplace")?name(1)?value } catch * { () }
        let $json-deathLat := try { $json("deathplace")?latitude } catch * { () }
        let $json-deathLng := try { $json("deathplace")?longitude } catch * { () }
        
        let $json-baptism :=
            try {
                for $e in $json("life_event")?*
                where some $n in $e?name?*
                      satisfies (map:get($n, "@language") = "de" and $n?name = "Taufe")
                return $e
            } catch * { () }
        let $json-baptismDate := try { $json-baptism?start_date } catch * { () }
        let $json-baptismPlace := try { $json-baptism?location?name(1)?value } catch * { () }
        let $json-baptismLat := try { $json-baptism?location?latitude } catch * { () }
        let $json-baptismLng := try { $json-baptism?location?longitude } catch * { () }
        
        let $json-burial :=
            try {
                for $e in $json("life_event")?*
                where some $n in $e?name?*
                      satisfies (map:get($n, "@language") = "de" and $n?name = "Beerdigung")
                return $e
            } catch * { () }
        
        let $json-burialDate := try { $json-burial?start_date } catch * { () }
        let $json-burialPlace := try { $json-burial?location?name(1)?value } catch * { () }
        let $json-burialLat := try { $json-burial?location?latitude } catch * { () }
        let $json-burialLng := try { $json-burial?location?longitude } catch * { () }

        
        let $json-professionOrOccupation :=
            try {
                for $p in $json("profession")?*
                let $de-name :=
                    for $n in $p?name?*
                    where map:get($n, "@language") = "de"
                    return $n?name
                where exists($de-name)
                return normalize-space($de-name)
            } catch * { () }
        let $json-gnd := try { $json("gnd")?value } catch * { () }
        let $json-bdid := try { $json("bdid") } catch * { () }
        let $json-pid := try { $json("pid") } catch * { () }

        let $xml-pid := $id
        
        let $shouldUpdate :=
            $size > 0 and
            exists($json-pid) and
            normalize-space(string($json-pid)) != "" and
            $json-pid = $xml-pid
        
        let $_ := (
            
            if ($shouldUpdate) then (
                for $x in $person
                        return update delete $x,
                        update insert
                            <person xmlns="http://www.tei-c.org/ns/1.0" xml:id="fpb-{$json-pid}">
                                <persName type="full">{$json-fullname}</persName>
                                {
                                    if (exists($json-birthDate)) then
                                        (<birth>
                                            <date when="{$json-birthDate}"/>
                                                {(if (exists($json-birthPlace)) then
                                                <placeName>{$json-birthPlace}</placeName>
                                                else (),
                                                if (exists($json-birthLat)) then
                                                <location>
                                                    <geo>{$json-birthLat}&#x20;{$json-birthLng}</geo>
                                                </location>
                                                else ())}
                                        </birth>)
                                    else
                                        (),
                                    if (exists($json-deathDate)) then
                                        (<death>
                                            <date when="{$json-deathDate}"/>
                                                {(if (exists($json-deathPlace)) then
                                                <placeName>{$json-deathPlace}</placeName>
                                                else (),
                                                if (exists($json-deathLat)) then
                                                <location>
                                                    <geo>{$json-deathLat}&#x20;{$json-deathLng}</geo>
                                                </location>
                                                else ())}
                                        </death>)
                                    else
                                        (),
                                    if (exists($json-baptism)) then
                                        (<event type="baptism">
                                            <desc>
                                                {(if (exists($json-baptismDate)) then
                                                <date when="{$json-baptismDate}"/>
                                                else (),
                                                if (exists($json-baptismPlace)) then
                                                <placeName>{$json-baptismPlace}</placeName>
                                                else (),
                                                if (exists($json-baptismLat)) then
                                                <location>
                                                    <geo>{$json-baptismLat}&#x20;{$json-baptismLng}</geo>
                                                </location>
                                                else ())}
                                            </desc>
                                        </event>)
                                    else
                                        (),
                                    if (exists($json-burial)) then
                                        (<event type="funeral">
                                            <desc>
                                                <date when="{$json-burialDate}"/>
                                                else (),
                                                if (exists($json-burialPlace)) then
                                                <placeName>{$json-burialPlace}</placeName>
                                                else (),
                                                if (exists($json-burialLat)) then
                                                <location>
                                                    <geo>{$json-burialLat}&#x20;{$json-burialLng}</geo>
                                                </location>
                                                else ())}
                                            </desc>
                                        </event>)
                                    else
                                        (),
                                    if (exists($json-professionOrOccupation)) then
                                        for $prof in $json-professionOrOccupation
                                        return
                                            <occupation>{$prof}</occupation>
                                    else
                                        (),
                                    if (exists($json-bdid)) then
                                        <note type='bdid'>
                                            <ptr type="bdid" target="https://www.bach-digital.de/receive/{$json-bdid}"/>
                                        </note>
                                    else
                                        (),
                                    if (exists($json-gnd)) then
                                        <note type='gnd'>
                                            <ptr type="gnd" target="https://d-nb.info/gnd/{$json-gnd}"/>
                                        </note>
                                    else
                                        ()
                                }
                                <ptr type="fpb" target="https://fpb.saw-leipzig.de/{$json-pid}"/>
                            </person> into $reg-doc//tei:listPerson
                    ) else ()
                )
        
              return map {
                  "id": $id,
                  "updated": if ($shouldUpdate) then true() else false()
              }
        
    let $placeResults :=
        for $place in $places
        let $id := substring-after($place/@xml:id, 'fpb-')
        let $url := "https://fpb.saw-leipzig.de/" || $id || "/json-ld/"
        let $json := try {
            json-doc($url)
        } catch * {
            ()
        }
        let $size := try {
            map:size($json) 
            } catch * { 
                () 
            }
        
        let $json-names := try { $json("name")?* } catch * { () }
        let $json-name-de := try { 
            for $n in $json-names
            where map:get($n, "@language") = "de"
            return $n("value")
        } catch * { () }
        let $json-lat := try { 
            string($json("latitude"))
        } catch * { () }
        let $json-lng := try { 
            string($json("longitude"))
        } catch * { () }
        let $json-gnd := try { $json("gnd") } catch * { () }
        let $json-geonames := try { 
          let $g := $json("geonames")
          return
              if(exists($g)) then
                  format-number($g, "0")
                  else ()
        } catch * { () }
        let $json-pid := try { $json("pid") } catch * { () }
    
        let $xml-pid := $id
        
        let $shouldUpdate :=
            $size > 0 and
            exists($json-pid) and
            normalize-space(string($json-pid)) != "" and
            $json-pid = $xml-pid
        
        let $_ := (
            
            if ($shouldUpdate) then (
                for $x in $place
                return 
                    update delete $x,
                    update insert
                        <place xmlns="http://www.tei-c.org/ns/1.0" xml:id="fpb-{$json-pid}">
                            {
                                for $n in $json-names
                                    where map:get($n, "@language") = "de"
                                    return <placeName type="full">{$n("value")}</placeName>,
                                if ($json-lat and $json-lng) then
                                    <location>
                                        <geo>{$json-lat}&#x20;{$json-lng}</geo>
                                    </location>
                                else (),
                                if ($json-gnd) then
                                    <note type="gnd">
                                        <ptr type="gnd" target="https://d-nb.info/gnd/{$json-gnd}"/>
                                    </note>
                                else (),
                                if ($json-geonames) then
                                    <note type="geonames">
                                        <ptr type="geo" target="https://www.geonames.org/{$json-geonames}"/>
                                    </note>
                                else ()
                            }
                            <ptr type="fpb" target="https://fpb.saw-leipzig.de/{$json-pid}"/>
                        </place>
                        into $reg-doc//tei:listPlace
                
            ) else ()
        )   
        return map {
              "id": $id,
              "updated": if ($shouldUpdate) then true() else false()
          }

    let $termResults :=
        for $term in $terms
        let $id := substring-after($term/@xml:id, 'fpb-')
        let $url := "https://fpb.saw-leipzig.de/" || $id || "/json-ld/"
        let $json := try {
            json-doc($url)
        } catch * {
            ()
        }
        let $size := try {
            map:size($json) 
            } catch * { 
                () 
            }
        
        let $json-names := try { $json("name")?* } catch * { () }
        let $json-name-de := try { 
            for $n in $json-names
            where map:get($n, "@language") = "de"
            return $n("name")
        } catch * { () }
        let $json-desc := try { $json("description")?* } catch * { () }
        let $json-desc-de := try { 
            for $d in $json-desc
            where map:get($d, "@language") = "de"
            return $d("description")
        } catch * { () }
        let $json-pid := try { $json("pid") } catch * { () }
    
        let $xml-pid := $id
        
        let $shouldUpdate :=
            $size > 0 and
            exists($json-pid) and
            normalize-space(string($json-pid)) != "" and
            $json-pid = $xml-pid
        
        let $_ := (
            
            if ($shouldUpdate) then (
                for $x in $term
                return 
                    update delete $x,
                    update insert
                        <nym xmlns="http://www.tei-c.org/ns/1.0" xml:id="fpb-{$json-pid}">
                            {
                                for $n in $json-names
                                    where map:get($n, "@language") = "de"
                                    return 
                                                <orth>
                                                    <term>{$n("name")}</term>
                                                </orth>
                                            ,
                                if (exists($json-desc)) then
                                    for $d in $json-desc
                                    where map:get($d, "@language") = "de"
                                    return <def>
                                                {$d("description")}
                                            </def>
                                else ()
                            }
                            <ptr type="fpb" target="https://fpb.saw-leipzig.de/{$json-pid}"/>
                        </nym>
                        into $reg-doc//tei:listNym
                
            ) else ()
        )   
        return map {
              "id": $id,
              "updated": if ($shouldUpdate) then true() else false()
          }
        
    let $whitespace-updates :=
        for $t in $reg-doc//text()[normalize-space(.) = ""]
        return update delete $t
    let $save := xmldb:store(
        $collection,
        $file,
        serialize($reg-doc, map { "method": "xml", "indent": true() })
    )
        
    let $duplicatedPersons :=
    for $id in distinct-values($persons/@xml:id)
        let $dups := $persons[@xml:id = $id]
        where count($dups) > 1
        return $id
    
    let $duplicatedPlaces :=
    for $id in distinct-values($places/@xml:id)
        let $dups := $places[@xml:id = $id]
        where count($dups) > 1
        return $id
    
    let $duplicatedTerms :=
    for $id in distinct-values($terms/@xml:id)
        let $dups := $terms[@xml:id = $id]
        where count($dups) > 1
        return $id
        
    return map {
        "status": "done",
        "persons": count(distinct-values($persons/@xml:id)),
        "duplicated-persons": $duplicatedPersons,
        "places": count(distinct-values($places/@xml:id)),
        "duplicated-places": $duplicatedPlaces,
        "terms": count(distinct-values($terms/@xml:id)),
        "duplicated-terms": $duplicatedTerms,
        "updated-persons-count": count($persResults[?updated = true()]),
        "updated-places-count": count($placeResults[?updated = true()]),
        "updated-terms-count": count($termResults[?updated = true()]),
        "not-updated-persons": count($persResults[?updated = false()]),
        "not-updated-places": count($placeResults[?updated = false()]),
        "not-updated-terms": count($termResults[?updated = false()]),
        "persResults": $persResults,
        "placeResults": $placeResults,
        "termResults": $termResults
    }
};

(: Postprocessing - If Closer or Opener  :)
declare function api:setTags($request as map(*)){
    let $body := $request?body
    let $path := xmldb:decode($request?parameters?id)
    let $srcDoc := config:get-document($path)
    let $abTags := $srcDoc//*/tei:text/tei:body//tei:ab
    let $hasAccess := sm:has-access(document-uri(root($srcDoc)), "rw-")
    let $attr := $srcDoc//tei:teiHeader/tei:revisionDesc[@status="status.final"]
    return
        if (not($hasAccess) and request:get-method() = 'PUT') then
            error($errors:FORBIDDEN, "Not allowed to write to " || $path)
        else if ($srcDoc) then
            if($attr) then
                for $ab in $abTags
                return update rename $ab as "tei:div"
            else
                "Das Dokument ist noch in Bearbeitung."
        else
            error($errors:NOT_FOUND, "Document " || $path || " not found")
};

(:  Validation :)
declare function api:validate($request as map(*)) {
    let $schema-uri := doc("https://www.tei-c.org/release/xml/tei/custom/schema/relaxng/tei_all.rng")
    let $path := xmldb:decode($request?parameters?id)
    let $doc := doc(xmldb:encode-uri($config:data-root || "/" || $path))
    let $clear := validation:clear-grammar-cache()
    let $report := validation:jing-report($doc, $schema-uri)
    let $result := 
    if(validation:jing($doc, $schema-uri) = true()) then
        "The document is VALID TEI"
    else
        (codepoints-to-string(13), "The document is NOT valid TEI !!!", codepoints-to-string((10, 13)),
                for $message in $report/message[@level = "Error"]
                return
                    ("&#10; &#x2022; Line ",$message/@line, ", Col. ", $message/@column, ": ", 
                        $message/text(), codepoints-to-string((10, 13))
                    ))
    return
        $result
};

(: Setting permissions - The code is a slightly modified version of the one at https://github.com/daliboris/theatrum-neolatinum-register-data/blob/main/modules/upload.xqm#L244-L257, kindly provided by Boris Lehečka IMPLEMENTED into collection xql now :)
declare function api:permission($request as map(*)) {
    let $collection := xmldb:decode-uri($request?parameters?collection)
    let $collectionPath := $config:data-root || "/" || $collection
    return if (xmldb:collection-available($collectionPath)) then
        let $file-permission := "rw-rw-r--"
        let $change := for $document in collection($collectionPath)
            let $filename := util:document-name($document)
            (: xs:anyURI($collectionPath || "/" || $filename) :)
            return sm:chmod(base-uri($document), $file-permission)
        return router:response(204,
                <result>Permission in collection {$collection} applied.</result>)
    else
        error($api:NOT_FOUND, "Collection not found: " || $collectionPath)
};
    
(: TODO: Personen, die als solche ausgezeichnet wurden, als Infos in Header packen / Personen, die unbekannt sind, ins Register packen / Connector zur Personendatenbank :)