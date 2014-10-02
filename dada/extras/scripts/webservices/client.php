<?php
error_reporting(E_ALL);
ini_set('display_errors', 'on');

require_once('DadaMailWebService.php'); 

function raw_digest($message, $private_key) { 
	$digest = hash_hmac ('sha256', $message, $private_key, true);
	$digest = base64_encode($digest);
	return $digest; 
}


$pub    = 'aaOKqoeobNoaJPyAMYHo'; 
$privy  = 'bju7EF35jHua5aYvdiEyboipDcBQo3eeRqCNfc4E'; 
$list   = 'example';
#$flavor = 'validate_subscription'; 
#$flavor = 'subscription'; 
$flavor  = 'mass_email'; 

#$addresses = array(); 
#array_push($addresses, ); 
/*
$params = [
    'addresses' => array(
        [
            'email'  => 'test+7@example.com',
            'fields' => [
                'favorite_color' => 'red', 
            ],
        ],
    ) 
];
*/
$params = [
    'subject' => 'my subject', 
    'format'  => 'html', 
    'message' => 'blah blah blah!'
];

print_r($params); 

$ws = new DadaMailWebService($pub, $privy);
#echo "<pre>";
#echo $ws->public_key; 
#echo "\n";
#echo $ws->private_key; 
#echo "\n";
#echo $ws->digest('hello!'); 
#echo "\n";

echo '<pre>'; 
echo $ws->request($list, $flavor, $params ); 
echo "\n";
echo "and, we're done."
	
?>