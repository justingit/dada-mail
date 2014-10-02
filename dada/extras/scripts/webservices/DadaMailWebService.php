<?php

Class DadaMailWebService { 

	public $public_key; 
	public $private_key; 
	
	public function __construct($public_key, $private_key) { 
		$this->public_key  = $public_key; 
		$this->private_key = $private_key; 
	}
	
	public function the_query_string($post_data){
		$raw_post_data  = http_build_query($post_data, null, "&", PHP_QUERY_RFC3986);
	    echo '$raw_post_data from client' . $raw_post_data . "\n"; 
		return $raw_post_data;
	}
	
	public function digest($message) { 
		$digest = hash_hmac ('sha256', $message, $this->private_key, true);
		$digest = base64_encode($digest);
		return $digest; 
	}
	
	public function nonce() {
	    $chars = array(); 
        foreach (range(0, 9) as $n) {
        	array_push($chars, $n);
        }
        foreach (range('a', 'z') as $l) {
        	array_push($chars, $l);
        }
        foreach (range('A', 'Z') as $L) {
        	array_push($chars, $L);
        }
        $num   = 8; 
        $nonce = ''; 
        foreach(range(1,$num) as $foo){
            $nonce .= $chars[rand(0, (count($chars)-1))];
        }

        return $nonce;
	}
	
	public function request($list, $flavor, $params){ 
	    
	    $nonce = time() . ':' . $this->nonce() ;

        if($flavor == 'mass_email'){ 
            $query_params = array(
                'format'    => $params['format'],
                'message'   => $params['message'],
                'nonce'     => $nonce,
                'subject'   => $params['subject'],
            ); 
        }
        else {
    		$encoded_addresses = json_encode($params['addresses']);
    		echo '$encoded_addresses' . $encoded_addresses . "\n"; 
    		$query_params = array(
    			'addresses' => $encoded_addresses,
    			'nonce'     => $nonce, 
    		);
    	}
        
		$rpd    =  $this->the_query_string($query_params);
		$digest =  $this->digest($rpd); 
		
		$request_method = 'POST';
	    $server = 'http://secret.dadademo.com/cgi-bin/dada/mail.cgi';
	    
		$request_w_path_info = $server . '/api/' . urlencode($list) . '/' . urlencode($flavor) . '/'; 
		
		//'. urlencode($this->public_key) . '/' . urlencode($digest) . '/
		
		
		// $http_host      = parse_url ($request_w_path_info, PHP_URL_HOST);
		// $request_uri    = parse_url ($request_w_path_info, PHP_URL_PATH);
		//$post_data      = $query_params;
		//$raw_post_data  = http_build_query ($post_data);

		// make the request using curl
		$ch = curl_init ();
		
		curl_setopt(
	    $ch,
	    CURLOPT_HTTPHEADER, 
	    array(
            'Authorization: hmac ' .  ' ' . $this->public_key . ':' . $digest,
            )
        );
            
		curl_setopt ($ch, CURLOPT_CONNECTTIMEOUT, 10); 
		curl_setopt ($ch, CURLOPT_URL, $request_w_path_info);
		curl_setopt ($ch, CURLOPT_POST, 1);
		
		$query = http_build_query($query_params);
		
		curl_setopt ($ch, CURLOPT_POSTFIELDS, $query);
		curl_setopt ($ch, CURLOPT_RETURNTRANSFER, 1);
		$response = curl_exec ($ch);
		curl_close ($ch);

		return $response; 
		
		//echo 'response' . $response; 
		//$res = json_decode ($response);
		//return $res; 
	}
}

?>