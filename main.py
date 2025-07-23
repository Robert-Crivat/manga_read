from flask import Flask, request, jsonify
from flask_cors import CORS
from bs4 import BeautifulSoup
import requests
import re
import json
import os
import time

app = Flask(__name__)
CORS(app)  # Abilita CORS per permettere chiamate da Flutter

def encode_keyword(keyword):
    return keyword.replace(' ', '%20')

def encode_keyword_cspecial(keyword):
    return keyword.replace('+','')

def encode_keyword_launch(keyword):
    return keyword.replace(' ', '-')

def remove_words_before_keyword(s, keyword):
    index = s.find(keyword)
    if index != -1:
        return s[index + len(keyword):]
    return s

def extract_manga_info_from_entry(entry):
    manga = {}
    # Thumbnail
    thumb_element = entry.select_one('a.thumb img')
    if thumb_element and 'src' in thumb_element.attrs:
        manga['thumbnail'] = thumb_element['src']
    # Titolo e link
    title_element = entry.select_one('a.manga-title')
    if title_element:
        manga['title'] = title_element.text.strip()
        manga['url'] = title_element.get('href', '')
    # Genere principale
    genre_element = entry.select_one('div.genre')
    if genre_element:
        manga['main_genre'] = genre_element.text.strip()
    # Status
    status_element = entry.select_one('div.status')
    if status_element:
        manga['status'] = status_element.text.strip()
    # Autore
    author_element = entry.select_one('div.author')
    if author_element:
        manga['author'] = author_element.text.strip()
    # Artista
    artist_element = entry.select_one('div.artist')
    if artist_element:
        manga['artist'] = artist_element.text.strip()
    # Generi aggiuntivi
    genres_element = entry.select_one('div.genres')
    if genres_element:
        manga['genres'] = genres_element.text.strip()
    # Trama
    story_element = entry.select_one('div.story')
    if story_element:
        manga['story'] = story_element.text.strip()
    return manga

@app.route('/search_manga')
def search_manga():
    keyword = request.args.get('keyword', '')
    response = requests.get('https://www.mangaworld.nz/archive?keyword=' + encode_keyword(keyword))
    result_list = []
    if response.status_code == 200:
        soup = BeautifulSoup(response.content, 'html.parser')
        manga_entries = soup.find_all('div', {'class': 'entry'})
        for entry in manga_entries:
            manga_info = extract_manga_info_from_entry(entry)
            if manga_info:
                result_list.append(manga_info)
    
    response_data = {
        "status": "ok",
        "messaggio": f"chiamata eseguita correttamente - search_manga(keyword={keyword})",
        "data": result_list
    }
    return jsonify(response_data)

@app.route('/manga_chapters')
def manga_chapters():
    url = request.args.get('link', '')
    response = requests.get(url)
    result_list = []
    if response.status_code == 200:
        soup = BeautifulSoup(response.content, 'html.parser')
        Manga = soup.find_all('a', {'class': 'chap'})
        for item in Manga:
            link = re.search('href="(.+?)"', str(item)).group(1)
            alt = re.search('title="(.+?)"', str(item)).group(1)
            if "read" in link:
                result_list.append({'link': link, 'alt': alt})
    result_list.reverse()
    response_data = {
        "status": "ok",
        "messaggio": f"chiamata eseguita correttamente - manga_chapters(link={url})",
        "data": result_list
    }
    
    return jsonify(response_data)

@app.route('/chapter_pages')
def chapter_pages():
    link = request.args.get('link', '')
    status = requests.get(str(link) + '/1?style=list')
    linkLetturaCapitolo = []
    total_pages = 0
    
    if status.status_code == 200:
        soup = BeautifulSoup(status.content, 'html.parser')
        
        # Estrai il numero totale di pagine dal link "last"
        last_page_element = soup.select_one('li.page-item.last a.page-link')
        if last_page_element:
            # Estrai il numero di pagina dall'attributo href o dal testo
            last_page_text = last_page_element.get_text().strip()
            last_page_match = re.search(r'>(\d+)<', str(last_page_element))
            
            if last_page_match:
                total_pages = int(last_page_match.group(1))
            elif last_page_text.isdigit():
                total_pages = int(last_page_text)
        
        # Se non riusciamo a trovare il totale, usa un valore di default
        if total_pages == 0:
            total_pages = 400
            
        print(f"Totale pagine rilevate: {total_pages}")
            
        # Ottieni tutte le immagini
        for i in range(1, total_pages + 1):
            lettura = soup.find_all('img', {'id': 'page-'+str(i)})
            match = re.search(r'src="(.*)"', str(lettura))
            if match:
                src = match.group(1)
                linkLetturaCapitolo.append(src)
    
    response_data = {
        "status": "ok",
        "messaggio": f"chiamata eseguita correttamente - trovate {len(linkLetturaCapitolo)} pagine",
        "total_pages": total_pages,
        "data": linkLetturaCapitolo
    }
    
    return jsonify(response_data)

@app.route('/all_manga')
def all_manga():
    # Ottieni parametri opzionali dalla richiesta
    page = request.args.get('page', default=1, type=int)
    max_pages = request.args.get('max_pages', default=1, type=int)
    
    # Calcola direttamente il numero di pagine da elaborare
    end_page = page + max_pages
    all_manga = []
    
    # Itera sulle pagine specificate
    for page_num in range(page, end_page):
        print(f"Elaborazione pagina {page_num}")
        page_url = f'https://www.mangaworld.nz/archive?page={page_num}'
        page_response = requests.get(page_url)
        if page_response.status_code == 200:
            page_soup = BeautifulSoup(page_response.content, 'html.parser')
            manga_entries = page_soup.find_all('div', {'class': 'entry'})
            for entry in manga_entries:
                manga_info = extract_manga_info_from_entry(entry)
                if manga_info:
                    all_manga.append(manga_info)
                    
    response_data = {
        "status": "ok",
        "messaggio": f"chiamata eseguita correttamente - all_manga (pagine {page}-{end_page-1})",
        "pagina_corrente": page,
        "pagine_elaborate": max_pages,
        "totale_manga": len(all_manga),
        "data": all_manga,
    }
    return jsonify(response_data)

@app.route('/getnovelsfire')
def getnovelsfire():
    """
    Estrae l'elenco delle novel da novelfire.net basandosi sulla nuova struttura HTML.
    Supporta la paginazione per recuperare tutte le novel disponibili.
    Versione aggiornata per la struttura HTML corrente (2025).
    """
    # URL base e parametri
    base_url = 'https://novelfire.net'
    novels_url = 'https://novelfire.net/genre-all/sort-new/status-all/all-novel'
    
    # Ottieni parametri opzionali dalla richiesta
    page = request.args.get('page', default=1, type=int)
    max_pages = request.args.get('max_pages', default=1, type=int)
    genre = request.args.get('genre', default='all', type=str)
    sort = request.args.get('sort', default='new', type=str)
    status = request.args.get('status', default='all', type=str)
    debug_mode = request.args.get('debug', 'false').lower() == 'true'
    
    # Costruisci URL con i parametri forniti
    if genre != 'all' or sort != 'new' or status != 'all':
        novels_url = f'{base_url}/genre-{genre}/sort-{sort}/status-{status}/all-novel'
    
    # Aggiungi paginazione se richiesto (se page > 1)
    if page > 1:
        novels_url = f'{novels_url}?page={page}'
    
    print(f"Fetching novels from: {novels_url}")
    
    # Headers aggiornati per simulare un browser reale
    import random
    user_agents = [
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36',
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Safari/605.1.15',
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.5060.53 Safari/537.36'
    ]
    
    headers = {
        'User-Agent': random.choice(user_agents),
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
        'Accept-Language': 'en-US,en;q=0.9,it;q=0.8',
        'Connection': 'keep-alive',
        'Cache-Control': 'max-age=0',
        'Referer': 'https://novelfire.net/',
        'sec-ch-ua': '"Chromium";v="112", "Google Chrome";v="112", "Not:A-Brand";v="99"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"Windows"',
        'Sec-Fetch-Dest': 'document',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-Site': 'same-origin',
        'Upgrade-Insecure-Requests': '1'
    }
    
    novels_list = []
    
    try:
        for current_page in range(page, page + max_pages):
            current_url = novels_url
            if current_page > 1:
                if '?' in current_url and current_page == page:
                    current_url = f'{current_url}&page={current_page}'
                else:
                    current_url = f'{current_url}{"?" if "?" not in current_url else "&"}page={current_page}'
            
            print(f"Processing page {current_page}: {current_url}")
            
            # Richiesta con gestione robusta di errori
            try:
                response = requests.get(current_url, headers=headers, timeout=30, verify=False)
                
                if response.status_code != 200:
                    print(f"Error fetching page {current_page}: HTTP {response.status_code}")
                    if debug_mode:
                        print(f"Response headers: {response.headers}")
                        print(f"Response content preview: {response.text[:500]}")
                    break
                
                # Forza encoding UTF-8
                response.encoding = 'utf-8'
                soup = BeautifulSoup(response.text, 'html.parser')
                
                if debug_mode:
                    print(f"Page content length: {len(response.text)} characters")
                
            except requests.exceptions.RequestException as e:
                print(f"Network error on page {current_page}: {str(e)}")
                continue
            
            # Strategia 1: Cerca il contenitore principale delle novel
            print("Cercando contenitore delle novel...")
            novel_items = []
            
            # Cerca prima 'ul.novel-list col6' come nell'HTML fornito
            novel_lists = soup.find_all('ul', class_='novel-list col6')
            if novel_lists:
                print(f"Trovati {len(novel_lists)} contenitori 'ul.novel-list col6'")
                for novel_list in novel_lists:
                    items = novel_list.find_all('li', class_='novel-item')
                    novel_items.extend(items)
            
            # Strategia 2: Cerca 'ul.novel-list' generico
            if not novel_items:
                novel_lists = soup.find_all('ul', class_='novel-list')
                if novel_lists:
                    print(f"Trovati {len(novel_lists)} contenitori 'ul.novel-list' generici")
                    for novel_list in novel_lists:
                        items = novel_list.find_all('li', class_='novel-item')
                        novel_items.extend(items)
            
            # Strategia 3: Cerca direttamente tutti i 'li.novel-item'
            if not novel_items:
                novel_items = soup.find_all('li', class_='novel-item')
                print(f"Trovati {len(novel_items)} elementi 'li.novel-item' diretti")
            
            # Strategia 4: Cerca nel contenitore #list-novel se esiste
            if not novel_items:
                novel_list_div = soup.find('div', id='list-novel')
                if novel_list_div:
                    novel_items = novel_list_div.find_all('li', class_='novel-item')
                    print(f"Trovati {len(novel_items)} elementi nel contenitore #list-novel")
            
            print(f"Found {len(novel_items)} novel items on page {current_page}")
            
            for item in novel_items:
                novel_info = {}
                
                try:
                    # Estrai il titolo e l'URL dal link principale
                    main_link = item.find('a', title=True)
                    if main_link:
                        novel_info['title'] = main_link.get('title', '').strip()
                        novel_info['url'] = main_link.get('href', '')
                        if novel_info['url'] and not novel_info['url'].startswith('http'):
                            novel_info['url'] = f"{base_url}{novel_info['url']}" if novel_info['url'].startswith('/') else f"{base_url}/{novel_info['url']}"
                    
                    # Se non trovato, prova con h4.novel-title
                    if not novel_info.get('title'):
                        title_elem = item.find('h4', class_='novel-title')
                        if title_elem:
                            novel_info['title'] = title_elem.get_text(strip=True)
                            # Trova il link associato
                            parent_link = title_elem.find_parent('a')
                            if parent_link:
                                novel_info['url'] = parent_link.get('href', '')
                                if novel_info['url'] and not novel_info['url'].startswith('http'):
                                    novel_info['url'] = f"{base_url}{novel_info['url']}" if novel_info['url'].startswith('/') else f"{base_url}/{novel_info['url']}"
                    
                    # Estrai l'immagine di copertina dalla figura
                    cover_img = item.select_one('figure.novel-cover img')
                    if cover_img:
                        image_url = None
                        
                        # Prova diversi attributi per l'immagine
                        for attr in ['src', 'data-src', 'data-original']:
                            if cover_img.has_attr(attr) and not cover_img[attr].startswith('data:'):
                                image_url = cover_img[attr]
                                break
                        
                        if image_url:
                            novel_info['cover_image'] = image_url
                            # Assicurati che l'URL sia completo
                            if novel_info['cover_image'].startswith('/'):
                                novel_info['cover_image'] = f"https://novelfire.net{novel_info['cover_image']}"
                            elif not novel_info['cover_image'].startswith('http'):
                                novel_info['cover_image'] = f"https://novelfire.net/{novel_info['cover_image']}"
                    
                    # Estrai il numero di capitoli dalle statistiche
                    stats_div = item.find('div', class_='novel-stats')
                    if stats_div:
                        # Cerca l'icona del libro e il testo dei capitoli
                        book_icon = stats_div.find('i', class_='icon-book-open')
                        if book_icon:
                            # Il testo dovrebbe essere nel contenitore padre dell'icona
                            chapters_text = stats_div.get_text(strip=True)
                            chapter_match = re.search(r'(\d+)\s*Chapters', chapters_text, re.IGNORECASE)
                            if chapter_match:
                                novel_info['chapters_count'] = int(chapter_match.group(1))
                            else:
                                # Se non riesce a parsare il numero, salva il testo completo
                                novel_info['chapters_count'] = chapters_text
                    
                    # Estrai eventuali badge (rating, stelle, ecc.)
                    badges = item.find_all('span', class_='badge')
                    if badges:
                        badge_info = {}
                        for badge in badges:
                            badge_text = badge.get_text(strip=True)
                            if 'R ' in badge_text:  # Rating badge
                                rating_match = re.search(r'R\s*(\d+)', badge_text)
                                if rating_match:
                                    badge_info['rating'] = int(rating_match.group(1))
                            elif re.search(r'\d+', badge_text):  # Altri badge numerici (stelle, ecc.)
                                star_match = re.search(r'(\d+)', badge_text)
                                if star_match:
                                    badge_info['stars'] = int(star_match.group(1))
                        
                        if badge_info:
                            novel_info['badges'] = badge_info
                    
                    # Aggiungi alla lista solo se abbiamo almeno titolo e URL
                    if novel_info.get('title') and novel_info.get('url'):
                        novels_list.append(novel_info)
                        if debug_mode and len(novels_list) <= 3:  # Debug solo per i primi 3
                            print(f"Novel estratta: {novel_info}")
                    
                except Exception as item_error:
                    print(f"Errore nell'estrazione di un elemento novel: {str(item_error)}")
                    continue
            
            # Se non troviamo novel items, interrompi il loop
            if not novel_items:
                print(f"Nessun elemento novel trovato nella pagina {current_page}, interruzione del loop")
                break
    
    except Exception as e:
        print(f"Error during novels extraction: {str(e)}")
        if debug_mode:
            import traceback
            print(f"Traceback completo: {traceback.format_exc()}")
    
    # Rimuovi duplicati basati sull'URL
    unique_novels = []
    seen_urls = set()
    
    for novel in novels_list:
        novel_url = novel.get('url', '')
        if novel_url and novel_url not in seen_urls:
            seen_urls.add(novel_url)
            unique_novels.append(novel)
    
    print(f"Total unique novels found: {len(unique_novels)}")
    
    # Aggiungi informazioni di debug se richiesto
    response_data = {
        "status": "ok",
        "messaggio": f"chiamata eseguita correttamente - getnovelsfire",
        "totale": len(unique_novels),
        "pagina_corrente": page,
        "pagine_elaborate": max_pages,
        "data": unique_novels
    }
    
    if debug_mode:
        response_data["debug_info"] = {
            "total_processed_pages": len(range(page, page + max_pages)),
            "novels_before_dedup": len(novels_list),
            "novels_after_dedup": len(unique_novels)
        }
    
    return jsonify(response_data)

@app.route('/get_novelfire_chapters')
def get_novelfire_chapters():
    """
    Estrae i capitoli disponibili per una novel specifica da novelfire.net.
    """
    url = request.args.get('url', '')
    if not url:
        return jsonify({
            "status": "error",
            "messaggio": "URL della novel non fornito",
            "data": []
        }), 400
    
    print(f"Fetching chapters from: {url}")
    
    headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
    'Accept-Language': 'en-US,en;q=0.9,it;q=0.8',
    'Accept-Encoding': 'gzip, deflate, br',
    'Connection': 'keep-alive',
    'Referer': 'https://novelfire.net/'
}
    
    if not url.endswith('/'):
        url = f"{url}/"
        
    chapter_url = f"{url}chapters"
    if 'chapters' not in url:
        chapter_url = f"{url}chapters"
    else:
        chapter_url = url
        
    response = requests.get(chapter_url, headers=headers)
    result_list = []
    
    if response.status_code == 200:
        soup = BeautifulSoup(response.content, 'html.parser')
        
        # Cerca il contenitore dei capitoli
        chapter_container = soup.find('div', {'id': 'chapterlist'})
        if not chapter_container:
            chapter_container = soup.find('ul', {'class': 'chapter-list'})
            
        if chapter_container:
            chapter_links = chapter_container.find_all('a')
            
            for link in chapter_links:
                href = link.get('href', '')
                if href and not href.startswith('#') and 'javascript:' not in href:
                    title = link.get_text(strip=True)
                    
                    if title and href:
                        if href.startswith('/'):
                            href = f"https://novelfire.net{href}"
                        
                        result_list.append({
                            'link': href,
                            'title': title
                        })
    
    # Rimuovi duplicati
    unique_chapters = []
    seen_urls = set()
    
    for chapter in result_list:
        if chapter['link'] not in seen_urls:
            seen_urls.add(chapter['link'])
            unique_chapters.append(chapter)
    
    print(f"Total chapters found: {len(unique_chapters)}")
    
    response_data = {
        "status": "ok",
        "messaggio": f"chiamata eseguita correttamente - get_novelfire_chapters(url={url})",
        "data": unique_chapters
    }
    
    return jsonify(response_data)

@app.route('/get_novelfire_chapter_content')
def get_novelfire_chapter_content():
    """
    Estrae il contenuto di un capitolo specifico da novelfire.net con robustezza migliorata.
    Versione ottimizzata per funzionare sia in locale che in remoto.
    Include meccanismi anti-blocco e diagnostica avanzata.
    """
    url = request.args.get('url', '')
    translation_mode = request.args.get('translation', 'default')
    debug_mode = request.args.get('debug', 'false').lower() == 'true'
    
    if not url:
        return jsonify({
            "status": "error",
            "messaggio": "URL del capitolo non fornito",
            "data": {}
        }), 400
    
    print(f"=== INIZIO ESTRAZIONE CAPITOLO ===")
    print(f"URL: {url}")
    print(f"Translation mode: {translation_mode}")
    print(f"Debug mode: {debug_mode}")
    
    # Lista di User-Agent a rotazione per evitare blocchi
    user_agents = [
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36',
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Safari/605.1.15',
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.5060.53 Safari/537.36',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/115.0',
        'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1'
    ]
    
    # Seleziona un User-Agent casuale
    import random
    random_user_agent = random.choice(user_agents)
    
    headers = {
        'User-Agent': random_user_agent,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9,it;q=0.8',
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
        'Cache-Control': 'max-age=0',
        'Referer': 'https://novelfire.net/',
        'sec-ch-ua': '"Chromium";v="112", "Google Chrome";v="112", "Not:A-Brand";v="99"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"Windows"',
        'Sec-Fetch-Dest': 'document',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-Site': 'same-origin',
        'Upgrade-Insecure-Requests': '1',
        'Pragma': 'no-cache'
    }
    
    # Aggiunge traduzione se richiesta
    if translation_mode != 'default' and 'translation=' not in url:
        separator = '&' if '?' in url else '?'
        url += f'{separator}translation={translation_mode}'
        print(f"URL con traduzione: {url}")
    
    # Informazioni di diagnostica per l'ambiente
    import platform
    import socket
    
    print(f"Sistema operativo: {platform.system()} {platform.release()}")
    print(f"Python version: {platform.python_version()}")
    try:
        hostname = socket.gethostname()
        ip_address = socket.gethostbyname(hostname)
        print(f"Hostname: {hostname}, IP: {ip_address}")
    except Exception as e:
        print(f"Errore nel recupero info di rete: {str(e)}")
    
    # Proxy configuration (disabilitato di default, attivabile per debug)
    proxies = None
    use_proxy = False
    if debug_mode and use_proxy:
        # Lista di proxy pubblici che potrebbero funzionare (da sostituire con proxy reali)
        proxy_list = [
            "http://proxy1.example.com:8080",
            "http://proxy2.example.com:8080"
        ]
        selected_proxy = random.choice(proxy_list)
        proxies = {
            "http": selected_proxy,
            "https": selected_proxy
        }
        print(f"Usando proxy: {selected_proxy}")
    
    # Estrattore di contenuto
    def extract_with_retry(max_retries=3):
        for attempt in range(max_retries):
            try:
                print(f"Tentativo {attempt+1}/{max_retries}")
                print("Effettuando richiesta HTTP...")
                
                # Aumenta timeout e disabilita verifica SSL per ambienti remoti con possibili problemi di rete
                response = requests.get(
                    url, 
                    headers=headers, 
                    timeout=30, 
                    allow_redirects=True, 
                    verify=False,
                    proxies=proxies
                )
                
                print(f"Status code: {response.status_code}")
                print(f"Content length: {len(response.content)} bytes")
                print(f"Content type: {response.headers.get('Content-Type', 'sconosciuto')}")
                print(f"Encoding originale: {response.encoding}")
                
                # Diagnostica headers della risposta
                print("Headers della risposta:")
                for key, value in response.headers.items():
                    print(f"  {key}: {value}")
                
                # Verifica se c'è un possibile blocco o captcha
                if "captcha" in response.text.lower() or "blocked" in response.text.lower() or "robot" in response.text.lower():
                    print("⚠️ RILEVATO POSSIBILE CAPTCHA O BLOCCO ANTI-BOT!")
                    # Se è l'ultimo tentativo, salviamo la risposta per diagnosi
                    if attempt == max_retries - 1 and debug_mode:
                        with open("blocked_response.html", "w", encoding="utf-8") as f:
                            f.write(response.text)
                        print("Risposta salvata in blocked_response.html")
                
                # Forza encoding a UTF-8
                response.encoding = 'utf-8'
                print(f"Encoding forzato a: {response.encoding}")
                
                if response.status_code != 200:
                    print(f"Errore HTTP {response.status_code}")
                    # Aggiungi backoff esponenziale
                    if attempt < max_retries - 1:
                        wait_time = 2 ** attempt
                        print(f"Attendo {wait_time} secondi prima del prossimo tentativo...")
                        time.sleep(wait_time)
                    continue
                
                # Verifica minima lunghezza contenuto
                if len(response.text) < 500:
                    print(f"Contenuto troppo breve ({len(response.text)} bytes), potenziale blocco!")
                    if attempt < max_retries - 1:
                        wait_time = 2 ** attempt
                        print(f"Attendo {wait_time} secondi prima del prossimo tentativo...")
                        time.sleep(wait_time)
                    continue
                
                return response
                
            except requests.exceptions.RequestException as e:
                print(f"Errore nella richiesta: {str(e)}")
                if attempt < max_retries - 1:
                    wait_time = 2 ** attempt
                    print(f"Attendo {wait_time} secondi prima del prossimo tentativo...")
                    time.sleep(wait_time)
                else:
                    print("Tutti i tentativi falliti")
                    return None
    
    # Esegui la richiesta con retry
    response = extract_with_retry()
    
    if not response:
        return jsonify({
            "status": "error",
            "messaggio": "Impossibile recuperare il contenuto dopo diversi tentativi",
            "data": {
                "title": "",
                "content": "Errore di connessione al server. Il sito potrebbe bloccare le richieste dal server.",
                "paragraphs": ["Errore di connessione al server. Il sito potrebbe bloccare le richieste dal server."],
                "prev_chapter": "",
                "next_chapter": "",
                "translation_mode": translation_mode,
                "error": True
            }
        })
    
    # Usa response.text invece di response.content per garantire la decodifica corretta
    try:
        soup = BeautifulSoup(response.text, 'html.parser')
        print("HTML parsato con BeautifulSoup usando response.text")
        
        # Verifica presenza di testo nella pagina per capire se è un blocco
        text_content = soup.get_text(strip=True)
        if len(text_content) < 1000:
            print(f"ATTENZIONE: La pagina contiene poco testo ({len(text_content)} caratteri). Possibile blocco.")
            
            # Salva il contenuto per debug
            if debug_mode:
                with open("low_content_response.html", "w", encoding="utf-8") as f:
                    f.write(response.text)
                print("Risposta a basso contenuto salvata in low_content_response.html")
                
    except Exception as e:
        print(f"Errore nel parsing di response.text: {str(e)}, tentativo con response.content")
        soup = BeautifulSoup(response.content, 'html.parser')
        print("HTML parsato con BeautifulSoup usando response.content")
    
    # === ESTRAZIONE TITOLO ===
    chapter_title = ""
    print("\n--- Ricerca titolo capitolo ---")
    
    # Prova vari selettori per il titolo
    title_selectors = [
        ('h1', {'class': 'chapter-title'}),
        ('h1', {'class': 'title'}),
        ('h1', {}),
        ('h2', {'class': 'chapter-title'}),
        ('h2', {'class': 'title'}),
        ('h2', {}),
        ('div', {'class': 'chapter-title'}),
        ('div', {'class': 'title'}),
        ('span', {'class': 'chapter-title'}),
        ('title', {})
    ]
    
    for tag, attrs in title_selectors:
        title_elem = soup.find(tag, attrs)
        if title_elem:
            chapter_title = title_elem.get_text(strip=True)
            if chapter_title and len(chapter_title) > 3:
                print(f"Titolo trovato con {tag} {attrs}: '{chapter_title}'")
                break
    
    # Pulisci il titolo
    if chapter_title:
        chapter_title = re.sub(r'\s*[-–|]\s*NovelFire.*$', '', chapter_title, flags=re.IGNORECASE)
        chapter_title = re.sub(r'\s*[-–|]\s*Novel\s*Fire.*$', '', chapter_title, flags=re.IGNORECASE)
        chapter_title = chapter_title.strip()
    
    print(f"Titolo finale: '{chapter_title}'")
    
    # === ESTRAZIONE CONTENUTO ===
    print("\n--- Ricerca contenuto capitolo ---")
    chapter_content = ""
    chapter_paragraphs = []
    
    # STRATEGIA 1: Cerca contenitori specifici del contenuto
    print("Strategia 1: Contenitori specifici...")
    content_selectors = [
        # Selettori più comuni per novel
        ('div', {'class': 'content-wrap'}),
        ('div', {'class': 'chapter-content'}),
        ('div', {'class': 'reading-content'}),
        ('div', {'class': 'chapter-text'}),
        ('div', {'class': 'text-content'}),
        ('div', {'class': 'novel-content'}),
        ('div', {'id': 'chapter-content'}),
        ('div', {'id': 'chaptercontent'}),
        ('div', {'id': 'chapter-c'}),
        ('div', {'id': 'content'}),
        ('article', {'class': 'content'}),
        ('article', {'class': 'post-content'}),
        ('section', {'class': 'content'}),
        # Selettori NovelFire specifici
        ('div', {'class': 'chapter-entity'}),
        ('div', {'class': 'chapter-inner'}),
        ('div', {'class': 'chapter'}),
        ('div', {'class': 'entry-content'}),
        ('div', {'class': 'post-entry'}),
        ('div', {'class': 'text-left'}),
        ('div', {'class': 'reader-content'}),
        ('div', {'class': 'page-content'}),
        ('main', {}),
        ('article', {})
    ]
    
    content_container = None
    for tag, attrs in content_selectors:
        container = soup.find(tag, attrs)
        if container:
            # Verifica che il contenitore abbia abbastanza testo
            text_content = container.get_text(strip=True)
            if len(text_content) > 100:  # Almeno 100 caratteri
                content_container = container
                print(f"Contenitore trovato: {tag} {attrs} (lunghezza: {len(text_content)})")
                break
    
    # STRATEGIA 2: Se non trovato, cerca contenitori con molti paragrafi
    if not content_container:
        print("Strategia 2: Cerca contenitori con molti paragrafi...")
        max_paragraphs = 0
        best_container = None
        
        for div in soup.find_all(['div', 'article', 'section', 'main']):
            p_count = len(div.find_all('p'))
            if p_count > max_paragraphs and p_count >= 3:
                text_content = div.get_text(strip=True)
                if len(text_content) > 200:  # Almeno 200 caratteri
                    max_paragraphs = p_count
                    best_container = div
        
        if best_container:
            content_container = best_container
            print(f"Contenitore trovato con {max_paragraphs} paragrafi")
    
    # STRATEGIA 3: Cerca il contenitore con più testo significativo
    if not content_container:
        print("Strategia 3: Cerca contenitore con più testo...")
        max_text_length = 0
        best_container = None
        
        for container in soup.find_all(['div', 'article', 'section', 'main']):
            # Esclude header, footer, nav, sidebar
            if container.get('class'):
                classes = ' '.join(container.get('class', []))
                if any(skip in classes.lower() for skip in ['header', 'footer', 'nav', 'sidebar', 'menu', 'ads', 'comment']):
                    continue
            
            text = container.get_text(strip=True)
            # Verifica che il testo sembri contenuto di un capitolo
            if len(text) > max_text_length and len(text) > 500:
                # Conta quante parole ci sono - un capitolo dovrebbe averne molte
                word_count = len(text.split())
                if word_count > 100:  # Almeno 100 parole
                    max_text_length = len(text)
                    best_container = container
        
        if best_container:
            content_container = best_container
            print(f"Contenitore trovato con {max_text_length} caratteri")
    
    # STRATEGIA 4: Cerca in base al testo visibile (ultimo tentativo)
    if not content_container:
        print("Strategia 4: Analisi generale della pagina...")
        
        # Rimuovi elementi sicuramente non utili
        for unwanted in soup.find_all(['script', 'style', 'meta', 'link', 'head', 'svg']):
            unwanted.decompose()
        
        # Cerca il body o html
        body = soup.find('body') or soup
        if body:
            content_container = body
            print("Usando body/html come contenitore")
    
    # === ESTRAZIONE DEL TESTO DAL CONTENITORE ===
    if content_container:
        print("\n--- Estrazione testo dal contenitore ---")
        
        # Rimuovi elementi indesiderati
        print("Rimozione elementi indesiderati...")
        unwanted_tags = ['script', 'style', 'meta', 'link', 'noscript', 'ins', 'iframe', 'svg']
        unwanted_classes = ['ads', 'advertisement', 'adsbygoogle', 'comment', 'disqus', 'share', 'social', 'header', 'footer', 'nav', 'menu', 'sidebar']
        
        for tag in unwanted_tags:
            for element in content_container.find_all(tag):
                element.decompose()
        
        for element in content_container.find_all():
            if element.get('class'):
                classes = ' '.join(element.get('class', []))
                if any(unwanted in classes.lower() for unwanted in unwanted_classes):
                    element.decompose()
        
        # Ottieni il testo senza caratteri non ASCII strani
        try:
            # METODO 1: Estrai da tutti i tag <p>
            print("Metodo 1: Estrazione da tag <p>...")
            paragraphs = content_container.find_all('p')
            print(f"Trovati {len(paragraphs)} tag <p>")
            
            for p in paragraphs:
                text = p.get_text(strip=True)
                # Filtra caratteri non stampabili eccetto newline, tab, ecc.
                text = ''.join(c for c in text if c.isprintable() or c in '\n\r\t')
                if text and len(text) > 5:  # Paragrafi con almeno 5 caratteri
                    chapter_paragraphs.append(text)
            
            print(f"Estratti {len(chapter_paragraphs)} paragrafi dai tag <p>")
            
            # METODO 2: Se pochi paragrafi, estrai da altri elementi testuali
            if len(chapter_paragraphs) < 3:
                print("Metodo 2: Estrazione da altri elementi...")
                chapter_paragraphs = []  # Reset
                
                text_elements = content_container.find_all(['p', 'div', 'span', 'li', 'blockquote'])
                for elem in text_elements:
                    # Evita elementi che contengono altri elementi di testo (per evitare duplicati)
                    if not elem.find_all(['p', 'div', 'span']) or elem.name == 'p':
                        text = elem.get_text(strip=True)
                        # Filtra caratteri non stampabili
                        text = ''.join(c for c in text if c.isprintable() or c in '\n\r\t')
                        if text and len(text) > 10:  # Testi significativi
                            chapter_paragraphs.append(text)
                
                print(f"Estratti {len(chapter_paragraphs)} paragrafi da elementi vari")
            
            # METODO 3: Se ancora pochi paragrafi, dividi per newline
            if len(chapter_paragraphs) < 3:
                print("Metodo 3: Divisione per newline...")
                chapter_paragraphs = []  # Reset
                
                raw_text = content_container.get_text('\n', strip=True)
                # Filtra caratteri non stampabili
                raw_text = ''.join(c for c in raw_text if c.isprintable() or c in '\n\r\t')
                lines = [line.strip() for line in raw_text.split('\n') if line.strip()]
                
                for line in lines:
                    if len(line) > 20:  # Solo linee significative
                        chapter_paragraphs.append(line)
                
                print(f"Estratti {len(chapter_paragraphs)} paragrafi dividendo per newline")
            
            # METODO 4: Ultima risorsa - tutto il testo
            if len(chapter_paragraphs) < 3:
                print("Metodo 4: Estrazione testo completo...")
                
                all_text = content_container.get_text(strip=True)
                # Filtra caratteri non stampabili
                all_text = ''.join(c for c in all_text if c.isprintable() or c in '\n\r\t')
                
                if len(all_text) > 100:
                    # Dividi in blocchi di circa 300-500 caratteri
                    chunk_size = 400
                    chapter_paragraphs = []
                    
                    for i in range(0, len(all_text), chunk_size):
                        chunk = all_text[i:i + chunk_size]
                        # Cerca un punto naturale di interruzione
                        if i + chunk_size < len(all_text):
                            last_period = chunk.rfind('. ')
                            last_newline = chunk.rfind('\n')
                            break_point = max(last_period, last_newline)
                            
                            if break_point > chunk_size // 2:  # Se il break point è ragionevole
                                chunk = chunk[:break_point + 1]
                        
                        if chunk.strip():
                            chapter_paragraphs.append(chunk.strip())
                    
                    print(f"Estratti {len(chapter_paragraphs)} blocchi di testo")
                    
            # METODO 5: Estrazione diretta dalla pagina HTML tramite regex (metodo di emergenza)
            if len(chapter_paragraphs) < 3:
                print("Metodo 5: Estrazione di emergenza tramite regex...")
                
                # Prova a trovare blocchi di testo tra tag
                raw_html = str(content_container)
                
                # Cerca testo tra tag che potrebbe essere contenuto del capitolo
                text_blocks = re.findall(r'>([^<>]{50,})<', raw_html)
                potential_paragraphs = []
                
                for block in text_blocks:
                    clean_block = block.strip()
                    # Filtra caratteri non stampabili
                    clean_block = ''.join(c for c in clean_block if c.isprintable() or c in '\n\r\t')
                    if clean_block and len(clean_block) > 50:
                        potential_paragraphs.append(clean_block)
                
                if potential_paragraphs:
                    chapter_paragraphs = potential_paragraphs
                    print(f"Estratti {len(chapter_paragraphs)} blocchi di testo tramite regex")
        except Exception as e:
            print(f"Errore durante l'estrazione del testo: {str(e)}")
            # In caso di errore, prova un approccio più semplice
            try:
                all_text = content_container.get_text(strip=True)
                all_text = ''.join(c for c in all_text if c.isprintable() or c in '\n\r\t')
                chapter_paragraphs = [all_text]
                print("Fallback a estrazione semplice dopo errore")
            except Exception as e2:
                print(f"Anche il fallback è fallito: {str(e2)}")
                chapter_paragraphs = ["Impossibile estrarre il contenuto. Errore interno."]
        
        # Filtra paragrafi vuoti o troppo corti
        chapter_paragraphs = [p for p in chapter_paragraphs if p and len(p) > 10]
        
        # DEBUG: Stampa i primi paragrafi trovati
        print(f"DEBUG: Paragrafi trovati: {len(chapter_paragraphs)}")
        for i, para in enumerate(chapter_paragraphs[:3]):  # Solo i primi 3
            print(f"Paragrafo {i+1}: '{para[:100]}...'")
        
        # Verifica finale se abbiamo paragrafi validi
        valid_paragraphs = []
        for p in chapter_paragraphs:
            # Conta i caratteri validi (lettere, numeri, punteggiatura comune)
            valid_chars = sum(1 for c in p if c.isalnum() or c in ',.!?;:"\'()- ')
            if valid_chars > len(p) * 0.7:  # Almeno 70% caratteri validi
                valid_paragraphs.append(p)
            else:
                print(f"Scartato paragrafo con troppi caratteri non validi: '{p[:30]}...'")
        
        chapter_paragraphs = valid_paragraphs
        
        # Controllo finale: rileva se il contenuto è probabilmente una pagina di errore o di login
        error_indicators = ["error", "404", "not found", "captcha", "login", "access", "denied", "blocked", "robot"]
        
        is_error_page = False
        if chapter_paragraphs:
            combined_text = " ".join(chapter_paragraphs).lower()
            error_keyword_count = sum(1 for keyword in error_indicators if keyword in combined_text)
            
            # Se ci sono molti indicatori di errore e pochi paragrafi, probabilmente è una pagina di errore
            if error_keyword_count >= 2 and len(chapter_paragraphs) < 5:
                print(f"ATTENZIONE: Rilevata possibile pagina di errore (indicatori: {error_keyword_count})")
                is_error_page = True
                
                # Aggiungi un paragrafo esplicativo per l'utente
                if debug_mode:
                    chapter_paragraphs.insert(0, "NOTA: Sembra che ci sia un problema di accesso al contenuto. Il sito potrebbe bloccare le richieste dal server.")
        
        # Costruisci il contenuto finale
        if chapter_paragraphs:
            chapter_content = '\n\n'.join(chapter_paragraphs)
            print(f"Contenuto finale: {len(chapter_content)} caratteri")
        else:
            chapter_content = "Contenuto non trovato o non accessibile."
            print("ERRORE: Nessun contenuto estratto!")
            # Tenta un ultimo approccio d'emergenza
            try:
                raw_html = str(soup)
                matches = re.findall(r'>([^<>]{30,})<', raw_html)
                if matches:
                    potential_paragraphs = [m.strip() for m in matches if len(m.strip()) > 30]
                    chapter_paragraphs = potential_paragraphs[:10]  # Primi 10 potenziali paragrafi
                    chapter_content = '\n\n'.join(chapter_paragraphs)
                    print(f"Recupero d'emergenza: {len(chapter_paragraphs)} paragrafi")
            except Exception as e:
                print(f"Anche il recupero d'emergenza è fallito: {str(e)}")
                
        # Se abbiamo contenuto ma nessun paragrafo, forza la divisione
        if chapter_content and len(chapter_paragraphs) == 0:
            print("FIXING: Contenuto presente ma nessun paragrafo - forzando divisione...")
            # Pulisci il testo da caratteri non stampabili
            chapter_content = ''.join(c for c in chapter_content if c.isprintable() or c in '\n\r\t')
            
            # Prova a dividere il contenuto esistente
            if '\n\n' in chapter_content:
                chapter_paragraphs = [p.strip() for p in chapter_content.split('\n\n') if p.strip()]
            elif '\n' in chapter_content:
                chapter_paragraphs = [p.strip() for p in chapter_content.split('\n') if p.strip() and len(p) > 20]
            else:
                # Dividi ogni 200 caratteri
                chunk_size = 200
                chapter_paragraphs = []
                for i in range(0, len(chapter_content), chunk_size):
                    chunk = chapter_content[i:i + chunk_size]
                    if chunk.strip():
                        chapter_paragraphs.append(chunk.strip())
            
            # Verifica nuovamente che i paragrafi non contengano caratteri binari
            chapter_paragraphs = [
                ''.join(c for c in p if c.isprintable() or c in '\n\r\t')
                for p in chapter_paragraphs
            ]
            
            print(f"Dopo fix: {len(chapter_paragraphs)} paragrafi")
    
    else:
        print("ERRORE: Nessun contenitore trovato!")
        chapter_content = "Contenuto non trovato. La struttura della pagina potrebbe essere cambiata."
        chapter_paragraphs = []
    
    # === ESTRAZIONE LINK NAVIGAZIONE ===
    print("\n--- Ricerca link navigazione ---")
    prev_link = ""
    next_link = ""
    
    # Selettori per link precedente
    prev_selectors = [
        ('a', {'class': 'prev-chapter'}),
        ('a', {'class': 'prev'}),
        ('a', {'class': 'previous'}),
        ('a', {'rel': 'prev'}),
        ('a', {'id': 'prev-chapter'}),
        ('a', {'id': 'prev'})
    ]
    
    # Selettori per link successivo
    next_selectors = [
        ('a', {'class': 'next-chapter'}),
        ('a', {'class': 'next'}),
        ('a', {'rel': 'next'}),
        ('a', {'id': 'next-chapter'}),
        ('a', {'id': 'next'})
    ]
    
    # Cerca link precedente
    for tag, attrs in prev_selectors:
        elem = soup.find(tag, attrs)
        if elem and elem.has_attr('href'):
            href = elem['href']
            if href and not href.startswith('#'):
                prev_link = href if href.startswith('http') else f"https://novelfire.net{href}"
                print(f"Link precedente trovato: {prev_link}")
                break
    
    # Cerca link successivo
    for tag, attrs in next_selectors:
        elem = soup.find(tag, attrs)
        if elem and elem.has_attr('href'):
            href = elem['href']
            if href and not href.startswith('#'):
                next_link = href if href.startswith('http') else f"https://novelfire.net{href}"
                print(f"Link successivo trovato: {next_link}")
                break
    
    # Fallback: cerca per testo
    if not prev_link:
        prev_elem = soup.find('a', text=lambda t: t and any(word in str(t).lower() for word in ['previous', 'prev', 'precedente', '←', '‹']))
        if prev_elem and prev_elem.has_attr('href'):
            href = prev_elem['href']
            if href and not href.startswith('#'):
                prev_link = href if href.startswith('http') else f"https://novelfire.net{href}"
                print(f"Link precedente trovato (testo): {prev_link}")
    
    if not next_link:
        next_elem = soup.find('a', text=lambda t: t and any(word in str(t).lower() for word in ['next', 'successivo', '→', '›']))
        if next_elem and next_elem.has_attr('href'):
            href = next_elem['href']
            if href and not href.startswith('#'):
                next_link = href if href.startswith('http') else f"https://novelfire.net{href}"
                print(f"Link successivo trovato (testo): {next_link}")
    
    # === PREPARAZIONE RISPOSTA ===
    print(f"\n=== RISULTATO ESTRAZIONE ===")
    print(f"Titolo: '{chapter_title}'")
    print(f"Paragrafi: {len(chapter_paragraphs)}")
    print(f"Contenuto lunghezza: {len(chapter_content)} caratteri")
    print(f"Link precedente: {prev_link}")
    print(f"Link successivo: {next_link}")
    
    # Controllo finale di qualità
    content_status = "ok"
    error_message = ""
    
    if len(chapter_paragraphs) < 3 and not is_error_page:
        content_status = "warning"
        error_message = "Trovati pochi paragrafi, possibile problema con l'estrazione."
    
    if len(chapter_content) < 200:
        content_status = "error"
        error_message = "Contenuto troppo breve, possibile blocco o pagina di errore."
    
    chapter_data = {
        "title": chapter_title,
        "content": chapter_content,
        "paragraphs": chapter_paragraphs,
        "prev_chapter": prev_link,
        "next_chapter": next_link,
        "translation_mode": translation_mode,
        "content_status": content_status,
        "content_length": len(chapter_content),
        "paragraphs_count": len(chapter_paragraphs),
        "error_message": error_message
    }
    
    response_data = {
        "status": "ok",
        "messaggio": "contenuto del capitolo recuperato con successo",
        "data": chapter_data
    }
    
    print("=== FINE ESTRAZIONE ===\n")
    return jsonify(response_data)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=True)
