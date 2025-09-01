xquery version "3.1";

module namespace anno="http://teipublisher.com/api/annotations/config";

declare namespace tei="http://www.tei-c.org/ns/1.0";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";

declare variable $anno:local-authority-file := $config:data-root || "/register.xml";

(:~
 : Create TEI for the given type, properties and content of an annotation and return it.
 : This function is called when annotations are merged into the original TEI.
 :)
declare function anno:annotations($type as xs:string, $properties as map(*)?, $content as function(*)) {
    switch ($type)
        case "person" return
            <persName xmlns="http://www.tei-c.org/ns/1.0" ref="{$properties?ref}">{$content()}</persName>
        case "place" return
            <placeName xmlns="http://www.tei-c.org/ns/1.0" ref="{$properties?ref}">{$content()}</placeName>
        case "organization" return
            <orgName xmlns="http://www.tei-c.org/ns/1.0" ref="{$properties?ref}">{$content()}</orgName>
        case "hi" return
            <hi xmlns="http://www.tei-c.org/ns/1.0" rend="{$properties?rend}">{$content()}</hi>
        case "del" return
            <del xmlns="http://www.tei-c.org/ns/1.0" rend="strikethrough" hand="{$properties?ref}{$properties?handdel}">
              {$content()}
            </del>
        case "abbr" return
            <choice xmlns="http://www.tei-c.org/ns/1.0"><abbr>{$content()}</abbr><expan>{$properties?expan}</expan></choice>
        case "sic" return
            <choice xmlns="http://www.tei-c.org/ns/1.0"><sic>{$content()}</sic><corr>{$properties?corr}</corr></choice>
        case "memo" return
            <note xmlns="http://www.tei-c.org/ns/1.0" hand="{$properties?ref}{$properties?hands}" type="{$properties?types}" subtype="person">{$content()}</note>
        case "commentary" return
            <note xmlns="http://www.tei-c.org/ns/1.0" type="commented">{$content()}<note type="note" n="" target="">{$properties?commentary}</note></note>
        case "marginalia" return
            <note xmlns="http://www.tei-c.org/ns/1.0" type="{$properties?margin_type}" place="{$properties?margin_place}" target="{$properties?margin_target}">{$content()}</note>
        case "note" return
            ($content(),<note xmlns="http://www.tei-c.org/ns/1.0" type="note" n="" target="">{$properties?note}</note>)
        case "anchor" return
            ($content(),<anchor xmlns="http://www.tei-c.org/ns/1.0" type="{$properties?typez}" n="{$properties?nn}" xml:id="{$properties?xmlid}"/>)
        case "head" return
            <head xmlns="http://www.tei-c.org/ns/1.0">{$content()}</head>
        case "salute" return
            <salute xmlns="http://www.tei-c.org/ns/1.0">{$content()}</salute>
        case "address" return
            <address xmlns="http://www.tei-c.org/ns/1.0"><addrLine xmlns="http://www.tei-c.org/ns/1.0">{$content()}</addrLine></address>
        case "signed" return
            <signed xmlns="http://www.tei-c.org/ns/1.0">{$content()}</signed> 
        case "dateline" return
            <dateline xmlns="http://www.tei-c.org/ns/1.0">{$content()}</dateline>
        case "postscript" return
            <postscript xmlns="http://www.tei-c.org/ns/1.0"><p xmlns="http://www.tei-c.org/ns/1.0">{$content()}</p></postscript>
        case "opener" return
            <opener xmlns="http://www.tei-c.org/ns/1.0">{$content()}</opener>
        case "closer" return
            <closer xmlns="http://www.tei-c.org/ns/1.0">{$content()}</closer>
        case "indentation" return
            (<orig xmlns="http://www.tei-c.org/ns/1.0" rend='indent' />, $content())
        case "pb" return
            <pb xmlns="http://www.tei-c.org/ns/1.0" n="{$properties?pb}" facs="{$properties?facs}" />
        case "term" return
            <term xmlns="http://www.tei-c.org/ns/1.0" key="{$properties?ref}{$properties?key}" type="{$properties?typeterms}">{$content()}</term>
        case "gloss" return
            <gloss xmlns="http://www.tei-c.org/ns/1.0">
                {
                for $prop in map:keys($properties)[. = ('targets', 'types')]
                return
                    attribute { $prop } { $properties($prop) },
                $content()
            }
            </gloss>
        case "rdg" return
            <rdg xmlns="http://www.tei-c.org/ns/1.0" hand="{$properties?ref}{$properties?handrdg}" type="{$properties?typerdg}" varSeq="{$properties?varSeq}">{$content()}</rdg>
        case "date" return
            <date xmlns="http://www.tei-c.org/ns/1.0">
            {
                let $valid-entries :=
                    for $i in (1, 2)
                    let $year := $properties('year[' || $i || ']')
                    let $month := $properties('month[' || $i || ']')
                    let $day := $properties('day[' || $i || ']')
                    where $year or $month or $day
                    return $i
                for $n in $valid-entries
                let $year := $properties('year[' || $n || ']')
                let $month := switch($properties('month[' || $n || ']'))
                                case "Januar" return '01'
                                case "Februar" return '02'
                                case "März" return '03'
                                case "April" return '04'
                                case "Mai" return '05'
                                case "Juni" return '06'
                                case "Juli" return '07'
                                case "August" return '08'
                                case "September" return '09'
                                case "Oktober" return '10'
                                case "November" return '11'
                                case "Dezember" return '12'
                                default return ()
                let $day := $properties('day[' || $n || ']')
                let $isLeap := if((xs:int($year) mod 4 = 0) and ((xs:int($year) mod 100 != 0) or xs:int($year) mod 400 = 0)) then 'true' else 'false'
                let $validYear := matches($year, '^\d{4}$')
                let $validDay := 
                    if ($month = '02') then
                        if ($isLeap = 'true') then
                            (xs:int($day) ge 1 and xs:int($day) le 29)   (: Februar hat 29 Tage im Schaltjahr, 28 im Nicht-Schaltjahr :)
                        else
                            (xs:int($day) ge 1 and xs:int($day) le 28)
                    else if ($month = '04' or $month = '06' or $month = '09' or $month = '11') then
                        (xs:int($day) ge 1 and xs:int($day) le 30)  (: Monate mit 30 Tagen haben nur Tage zwischen 1 und 30 :)
                    else
                        (xs:int($day) ge 1 and xs:int($day) le 31)  (: Alle anderen Monate haben 31 Tage :)  
                let $dates := 
                    if ($year and $month and $day and $validDay and $validYear) then 
                        string-join(($year, $month, $day), '-')
                    else if($year and $month and $day and (not($validDay) or not($validYear))) then
                        error($errors:UNPROCESSABLE_ENTITY)
                    else if($year and $month and $validYear) then
                        string-join(($year, $month), '-')
                    else if($year and $month and not($validYear)) then
                        error($errors:UNPROCESSABLE_ENTITY)
                    else if($month and $day and $validDay) then
                        concat('--',$month, '-', $day)
                    else if($month and $day and not($validDay)) then 
                        error($errors:UNPROCESSABLE_ENTITY)
                    else if($year and $validYear) then
                        $year
                    else if($year and not($validYear)) then
                        error($errors:UNPROCESSABLE_ENTITY)
                    else if($month) then
                        concat('--', $month)
                    else if($day) then
                        concat('---', $day)
                    else ()
                return
                    if ($dates) then
                        let $form := $properties('date-form[' || $n || ']')
                        return
                            if ($form = 'when') then attribute {'when'} {$dates}
                            else if ($form = 'from') then attribute {'from'} {$dates}
                            else if ($form = 'to') then attribute {'to'} {$dates}
                            else if ($form = 'notBefore') then attribute {'notBefore'} {$dates}
                            else if ($form = 'notAfter') then attribute {'notAfter'} {$dates}
                            else ()
                    else (),
                $content()
            }
            </date>
        case "ref" return
            <ref xmlns="http://www.tei-c.org/ns/1.0" target="{$properties?target}">{$content()}</ref>
        case "rs" return
            <rs xmlns="http://www.tei-c.org/ns/1.0" type="{$properties?typers}" key="{$properties?ref}{$properties?key}">{$content()}</rs>
        case "add" return
            <add xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$properties?xmlid}" hand="{$properties?ref}{$properties?hand}" type="{$properties?types}" place="{$properties?place}" >{$content()}</add>
        case "supplied" return
            ($content(), <supplied xmlns="http://www.tei-c.org/ns/1.0" reason="{$properties?reason}" resp="{$properties?resp}">{$properties?supplied}</supplied>)
        case "handShift" return
            (<handShift xmlns="http://www.tei-c.org/ns/1.0" scribe="{$properties?ref}{$properties?scribe}" />, $content())
        case "latintype" return
            <hi xmlns="http://www.tei-c.org/ns/1.0" rend="latintype">
              {$content()}
            </hi>
        case "underline" return
            <hi xmlns="http://www.tei-c.org/ns/1.0" rend="underline">
              {$content()}
            </hi>
        case "semibold" return
            <hi xmlns="http://www.tei-c.org/ns/1.0" rend="semibold">
              {$content()}
            </hi>
        case "superscript" return
            <hi xmlns="http://www.tei-c.org/ns/1.0" rend="superscript">
              {$content()}
            </hi>
        case "emph" return
            <emph xmlns="http://www.tei-c.org/ns/1.0" rend="letter-spacing">
              {$content()}
            </emph>
        case "unclear" return
            <unclear xmlns="http://www.tei-c.org/ns/1.0" reason="{$properties?reasons}">{$content()}</unclear>
        case "mp" return
            <choice xmlns="http://www.tei-c.org/ns/1.0"><abbr xmlns="http://www.tei-c.org/ns/1.0" type="mp">
                {$content()}
            </abbr><expan xmlns="http://www.tei-c.org/ns/1.0">manu propria = mit eigener Hand</expan></choice>
        case "perge" return
            <hi xmlns="http://www.tei-c.org/ns/1.0" rend="latintype"><choice xmlns="http://www.tei-c.org/ns/1.0"><abbr xmlns="http://www.tei-c.org/ns/1.0" type="perge">
                {$content()}
            </abbr><expan xmlns="http://www.tei-c.org/ns/1.0">perge = et cetera</expan></choice></hi>
        case "keepLineBreaks" return
            (<orig xmlns="http://www.tei-c.org/ns/1.0" rend='keepLB' />, $content())
        case "seg" return
            <seg xmlns="http://www.tei-c.org/ns/1.0" type="todo">{$content()}</seg>
        case "title" return
            <title xmlns="http://www.tei-c.org/ns/1.0">{$content()}</title>
        case "paragraph" return
            <p xmlns="http://www.tei-c.org/ns/1.0">{$content()}</p>
        case "edit" return
            $properties?content
        default return
            $content()
};

(:~
 : Search for existing occurrences of annotations of the given type and key
 : in the data collection.
 :
 : Used to display the occurrence count next to authority entries.
 :)
declare function anno:occurrences($type as xs:string, $key as xs:string) {
    switch ($type)
        case "person" return
            collection($config:data-default)//tei:persName[@ref = $key]
        case "place" return
            collection($config:data-default)//tei:placeName[@ref = $key]
        case "term" return
            collection($config:data-default)//tei:term[@key = $key]
        case "organization" return
            collection($config:data-default)//tei:orgName[@ref = $key]
         default return ()
};

(:~
 : Create a local copy of an authority record based on the given type, id and data
 : passed in by the client.
 :)
declare function anno:create-record($type as xs:string, $id as xs:string, $data as map(*)) {
    switch ($type)
        case "place" return
            <place xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$id}">
                <placeName type="full">{$data?name}</placeName>
                {
                    if (exists($data?lat) and exists($data?lng)) then
                        <location>
                            <geo>{$data?lat}&#x20;{$data?lng}</geo>
                        </location>
                    else
                        ()
                }
                <ptr type="fpb" target="https://fpb.saw-leipzig.de/places/place/{$data?link}"/>
                {if (exists($data?geonames)) then
                    <note type="geo">
                        <ptr type="geo" target="https://geonames.org/{$data?geonames}"/>
                    </note>
                else (),
                if (exists($data?gnd)) then
                    <note type="gnd">
                        <ptr type="gnd" target="https://d-nb.info/gnd/{$data?gnd}"/>
                    </note>
                else ()
                }
                
            </place>
        case "person" return
            <person xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$id}">
                <persName type="full">{$data?name}</persName>
                {
                    if (exists($data?birthDate)) then
                        (<birth>
                            <date when="{$data?birthDate}"/>
                                {(if (exists($data?birthPlace)) then
                                <placeName>{$data?birthPlace}</placeName>
                                else (),
                                if (exists($data?birthLat)) then
                                <location>
                                    <geo>{$data?birthLat}&#x20;{$data?birthLng}</geo>
                                </location>
                                else ())}
                        </birth>)
                    else
                        (),
                    if (exists($data?deathDate)) then
                        (<death>
                            <date when="{$data?deathDate}"/>
                                {(if (exists($data?deathPlace)) then
                                <placeName>{$data?deathPlace}</placeName>
                                else (),
                                if (exists($data?deathLat)) then
                                <location>
                                    <geo>{$data?deathLat}&#x20;{$data?deathLng}</geo>
                                </location>
                                else ())}
                        </death>)
                    else
                        (),
                    if (exists($data?baptismDate)) then
                        (<event type="baptism">
                            <desc>
                                <date when="{$data?baptismDate}"/>
                                {(if (exists($data?baptismPlace)) then
                                <placeName>{$data?baptismPlace}</placeName>
                                else (),
                                if (exists($data?baptismLat)) then
                                <location>
                                    <geo>{$data?baptismLat}&#x20;{$data?baptismLng}</geo>
                                </location>
                                else ())}
                            </desc>
                        </event>)
                    else
                        (),
                    if (exists($data?burialDate)) then
                        (<event type="burial">
                            <desc>
                                <date when="{$data?burialDate}"/>
                                {(if (exists($data?burialPlace)) then
                                <placeName>{$data?burialPlace}</placeName>
                                else (),
                                if (exists($data?burialLat)) then
                                <location>
                                    <geo>{$data?burialLat}&#x20;{$data?burialLng}</geo>
                                </location>
                                else ())}
                            </desc>
                        </event>)
                    else
                        (),
                    if (exists($data?professionOrOccupation)) then
                        for $prof in $data?professionOrOccupation?*
                        return
                            <occupation>{$prof}</occupation>
                    else
                        (),
                    if (exists($data?bdid)) then
                        <note type='bdid'>
                            <ptr type="bdid" target="https://www.bach-digital.de/{$data?bdid}"/>
                        </note>
                    else
                        (),
                    if (exists($data?gnd)) then
                        <note type='gnd'>
                            <ptr type="gnd" target="https://d-nb.info/gnd/{$data?gnd}"/>
                        </note>
                    else
                        ()
                }
                <ptr type="fpb" target="https://fpb.saw-leipzig.de/person/person/{$data?link}"/>
            </person>
        case "organization" return
            <org xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$id}">
                <orgName type="full">{$data?name}</orgName>
                {
                    if (exists($data?place)) then
                    (<place>    
                        {(if (exists($data?place)) then
                            <placeName>{$data?place}</placeName>
                        else 
                            (),
                        if(exists($data?lat) and exists($data?lng)) then
                            <location>
                                <geo>{$data?lat}&#x20;{$data?lng}</geo>
                            </location>
                        else 
                            ())}
                    </place>)
                    else()
                }
                <ptr type="fpb" target="https://fpb.saw-leipzig.de/places/institution/{$data?link}"/>
                {if (exists($data?geonames)) then
                    <note type="geo">
                        <ptr type="geo" target="https://geonames.org/{$data?geonames}"/>
                    </note>
                else (),
                if (exists($data?gnd)) then
                    <note type="gnd">
                        <ptr type="gnd" target="https://d-nb.info/gnd/{$data?gnd}"/>
                    </note>
                else (),
                if (exists($data?viaf)) then
                    <note type="viaf">
                        <ptr type="viaf" target="http://viaf.org/viaf/{$data?viaf}"/>
                    </note>
                else (),
                if (exists($data?isil)) then
                    <note type="isil">
                        <ptr type="isil" target="https://sigel.staatsbibliothek-berlin.de/suche?isil={$data?isil}"/>
                    </note>
                else (),
                if (exists($data?rism)) then
                    <note type="rism">RISM-Sigle: {$data?rism}</note>
                else ()
                }
            </org>
        case "term" 
            return 
             <nym xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$id}">
                <orth>
                    <term>{$data?title}</term>
                </orth>
                <def>{$data?desc}
                    <ptr type="fpb" target="https://fpb.saw-leipzig.de/glossary/{$data?link}"/>
                </def>
            </nym>
        default return
            ()
};

(:~
 : Query the local register for existing authority entries matching the given type and query string. 
 :)
declare function anno:query($type as xs:string, $query as xs:string?) {
    try {
        switch ($type)
            case "place" return
                for $place in doc($anno:local-authority-file)//tei:place[ft:query(tei:placeName, $query)]
                return
                    map {
                        "id": $place/@xml:id/string(),
                        "label": $place/tei:placeName[@type="full"]/string(),
                        "link": $place/tei:ptr[@type='fpb']/@target/string()
                    }
            case "person" return
                for $person in doc($anno:local-authority-file)//tei:person[ft:query(tei:persName, $query)]
                let $birth := $person/tei:birth/tei:date/@when
                let $death := $person/tei:death/tei:date/@when
                let $dates := 
                    if ($birth) then
                        concat('*',$birth,' ✝',$death)
                    else
                        ()
                return
                    map {
                        "id": $person/@xml:id/string(),
                        "label": $person/tei:persName[@type="full"]/string(),
                        "details": ``[`{$dates}`; `{$person/tei:occupation/string()}`, `{$person/tei:note/string()}`]``,
                        "link": $person/tei:ptr[@type='fpb']/@target/string()
                    }
            case "organization" return
                for $org in doc($anno:local-authority-file)//tei:org[ft:query(tei:orgName, $query)]
                return
                    map {
                        "id": $org/@xml:id/string(),
                        "label": $org/tei:orgName[@type="full"]/string(),
                        "link": $org/tei:ptr[@type='fpb']/@target/string()
                    }
            case "term" return
                for $term in doc($anno:local-authority-file)//tei:listNym[ft:query(tei:nym/tei:orth/tei:term, $query)]
                return
                    map {
                        "id": $term/ancestor::tei:nym/@xml:id/string(),
                        "label": $term/string(),
                        "link": $term/ancestor::tei:nym/tei:def/tei:ptr[@type='fpb']/@target/string()
                    }
            default return
                ()
    } catch * {
        ()
    }
};

(:~
 : Return the insertion point to which a local authority record should be appended
 : when creating a local copy.
 :)
declare function anno:insert-point($type as xs:string) {
    switch ($type)
        case "place" return
            doc($anno:local-authority-file)//tei:listPlace
        case "organization" return
            doc($anno:local-authority-file)//tei:listOrg
        case "term" return
            doc($anno:local-authority-file)//tei:listNym
         case "person" return
            doc($anno:local-authority-file)//tei:listPerson
        default return
            doc($anno:local-authority-file)//tei:listPerson
};

(:~
 : For the given local authority entry, return a sequence of other strings (e.g. alternate names) 
 : which should be used when parsing the text for occurrences.
 :)
declare function anno:local-search-strings($type as xs:string, $entry as element()?) {
    switch($type)
        case "place" return $entry/tei:placeName/string()
        case "organization" return $entry/tei:orgName/string()
        case "term" return $entry/tei:orth/tei:term/string()
        default return $entry/tei:persName/string()
};