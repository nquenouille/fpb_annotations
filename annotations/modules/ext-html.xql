xquery version "3.1";
(:~ : Non-standard extension functions, mainly used for the documentation. :)

module namespace pmf="http://www.tei-c.org/tei-simple/xquery/ext-html";
declare namespace tei="http://www.tei-c.org/ns/1.0";
import module namespace html="http://www.tei-c.org/tei-simple/xquery/functions";


(: Behaviour for facs :)
declare function pmf:facs-lb($config as map(*), $node as node(), $class as xs:string+, $content) {
    let $facs := replace(replace($node/@facs, '/[^/]*$', ''), 'iiif:', '')
    let $coords := (replace($node/@facs, '^.*/', ''))
    let $inside-table := boolean($node/ancestor::tei:table)
    return 
        if ($inside-table) then
            (<span class="{$class} line-marker" data-image="{$facs}" data-coords="{$coords}"/>,
                if ($node/@break = 'no') then 
                ()
            else
                text { ' ' }
            )
        else
        (
        <br class="{$class} line-marker" data-image="{$facs}" data-coords="{$coords}"/>,
        if ($node/@break = 'no') then
            ()
        else
            text { ' ' }
    )
};

(: Behaviour for date :)
declare function pmf:date(
    $config as map(*),
    $node as node(),
    $class as xs:string*,
    $content
) {

    let $alternate :=
        if ($node/@when) then
            pmf:convertDates(string($node/@when))
        else if ($node/@from and $node/@notAfter) then    
            concat('Vom ', pmf:convertDates(string($node/@from)), ' an und nicht nach ', pmf:convertDates(string($node/@notAfter)))
        else if($node/@notBefore and $node/@to) then
            concat('Nicht vor ', pmf:convertDates(string($node/@notBefore)), ' und bis ', pmf:convertDates(string($node/@to)))
        else if ($node/@from and $node/@to) then
            concat(
                'Vom ',
                pmf:convertDates(string($node/@from)),
                ' bis ',
                pmf:convertDates(string($node/@to))
            )
        else if ($node/@from) then
            concat(
                'Vom ',
                pmf:convertDates(string($node/@from)),
                ' an'
            )
        else if ($node/@to) then
            concat(
                'Bis ',
                pmf:convertDates(string($node/@to))
            )
        else if ($node/@notBefore and $node/@notAfter) then
            concat('Nicht vor ', pmf:convertDates(string($node/@notBefore)), ' und nicht nach ', pmf:convertDates(string($node/@notAfter)))
        else if ($node/@notBefore) then
            concat('Nicht vor ', pmf:convertDates(string($node/@notBefore)))
        else if ($node/@notAfter) then
            concat('Nicht nach ', pmf:convertDates(string($node/@notAfter)))
        else ()

    let $default :=
    if ($node/@when) then
        <time datetime="{string($node/@when)}">
            {$content}
        </time>
    else
        $content
        
    return
        <pb-popover placement="bottom"
                    fallback-placement="right"
                    trigger="mouseenter focus click">
            <span slot="default" class="{string-join($class, ' ')}">
                {$default}
            </span>
            <span slot="alternate">
                {$alternate}
            </span>
            <span class="sr-only">
                {$alternate}
            </span>
        </pb-popover>
};
    
declare function pmf:convertDates($date as xs:string?) as xs:string? {
    let $date-pattern := matches($date, '^\d{4}-\d{2}-\d{2}$')
    let $year-month-pattern := matches($date, '^\d{4}-\d{2}$')
    let $month-day-pattern := matches($date, '^--\d{2}-\d{2}$')
    let $year-only-pattern := matches($date, '^\d{4}$') 
    let $day-only-pattern := matches($date, '^---\d{2}$')
    let $month-only-pattern := matches($date, '^--\d{2}$')
    let $months := ('Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember') 
    return
        if ($date-pattern) then 
            let $month := substring($date, 6, 2)
            let $month-index := xs:int($month)
            let $day := substring($date, 9, 2)
            let $year := substring($date, 1, 4) 
            return 
                concat($day, '. ', $months[$month-index], ' ', $year) 
        else if ($year-month-pattern) then
            let $month := substring($date, 6, 2)
            let $month-index := xs:int($month)
            let $year := substring($date, 1, 4)
            return 
                concat($months[$month-index], ' ', $year)
        else if ($month-day-pattern) then
            let $month := substring($date, 3, 2)
            let $month-index := xs:int($month)
            let $day := substring($date, 6,2)
            return 
                concat($day, '. ', $months[$month-index])
        else if ($day-only-pattern) then
            let $day := substring($date, 4, 2)
            return 
                concat($day, '. Tag eines unbekannten Monats')
        else if ($month-only-pattern) then
            let $month := substring($date, 3, 2)
            let $month-index := xs:int($month)
            return $months[$month-index]
        else if ($year-only-pattern) then
            let $year := substring($date, 1, 4)
            return 
                $year
        else ()
};
