from flask import Flask, request, jsonify, Response
from flask_cors import CORS
from bs4 import BeautifulSoup
import requests
import re
import json
import os
import time
import base64
import logging
import cloudscraper
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
import cloudscraper 

app = Flask(__name__)
CORS(app)  # Abilita CORS per permettere chiamate da Flutter

# Configurazione logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

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

def mangaWorldExtraction(entry):
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

def mangaWorldMetaExtraction(meta_div):
    """
    Estrae informazioni dettagliate dal div.meta-data del manga
    Gestisce la nuova struttura HTML con titoli alternativi, generi multipli, ecc.
    """
    manga_info = {}
    
    if not meta_div:
        return manga_info
    
    # Trova tutti i div col-12 e col-md-6 che contengono le informazioni
    info_divs = meta_div.find_all('div', class_=re.compile(r'col-12|col-md-6'))
    
    for div in info_divs:
        text_content = div.get_text(strip=True)
        
        # Titoli alternativi
        if 'Titoli alternativi:' in text_content:
            alt_titles = text_content.replace('Titoli alternativi:', '').strip()
            if alt_titles:
                manga_info['alternative_titles'] = alt_titles
        
        # Generi (estrae i link dei badge)
        elif 'Generi:' in text_content:
            genre_badges = div.find_all('a', class_='badge')
            if genre_badges:
                genres = [badge.get_text(strip=True) for badge in genre_badges]
                manga_info['genres'] = genres
                manga_info['genres_text'] = ', '.join(genres)
        
        # Autore
        elif 'Autore:' in text_content:
            author_link = div.find('a')
            if author_link:
                manga_info['author'] = author_link.get_text(strip=True)
                manga_info['author_url'] = author_link.get('href', '')
            else:
                author_text = text_content.replace('Autore:', '').strip()
                if author_text:
                    manga_info['author'] = author_text
        
        # Artista
        elif 'Artista:' in text_content:
            artist_link = div.find('a')
            if artist_link:
                manga_info['artist'] = artist_link.get_text(strip=True)
                manga_info['artist_url'] = artist_link.get('href', '')
            else:
                artist_text = text_content.replace('Artista:', '').strip()
                if artist_text:
                    manga_info['artist'] = artist_text
        
        # Tipo
        elif 'Tipo:' in text_content:
            type_link = div.find('a')
            if type_link:
                manga_info['type'] = type_link.get_text(strip=True)
                manga_info['type_url'] = type_link.get('href', '')
            else:
                type_text = text_content.replace('Tipo:', '').strip()
                if type_text:
                    manga_info['type'] = type_text
        
        # Stato
        elif 'Stato:' in text_content:
            status_link = div.find('a')
            if status_link:
                manga_info['status'] = status_link.get_text(strip=True)
                manga_info['status_url'] = status_link.get('href', '')
            else:
                status_text = text_content.replace('Stato:', '').strip()
                if status_text:
                    manga_info['status'] = status_text
        
        # Visualizzazioni
        elif 'Visualizzazioni:' in text_content:
            views_span = div.find('span')
            if views_span and views_span.get_text(strip=True).isdigit():
                manga_info['views'] = int(views_span.get_text(strip=True))
            else:
                views_text = text_content.replace('Visualizzazioni:', '').strip()
                if views_text.isdigit():
                    manga_info['views'] = int(views_text)
        
        # Anno di uscita
        elif 'Anno di uscita:' in text_content:
            year_link = div.find('a')
            if year_link:
                year_text = year_link.get_text(strip=True)
                if year_text.isdigit():
                    manga_info['release_year'] = int(year_text)
                manga_info['release_year_url'] = year_link.get('href', '')
            else:
                year_text = text_content.replace('Anno di uscita:', '').strip()
                if year_text.isdigit():
                    manga_info['release_year'] = int(year_text)
        
        # Fansub
        elif 'Fansub:' in text_content:
            fansub_link = div.find('a')
            if fansub_link:
                manga_info['fansub'] = fansub_link.get_text(strip=True)
                manga_info['fansub_url'] = fansub_link.get('href', '')
            else:
                fansub_text = text_content.replace('Fansub:', '').strip()
                if fansub_text:
                    manga_info['fansub'] = fansub_text
    
    return manga_info

def mangaKatanaExtraction(entry):
    manga = {}
    
    # Thumbnail
    thumb_element = entry.select_one('div.wrap_img img')
    if thumb_element and 'src' in thumb_element.attrs:
        manga['thumbnail'] = thumb_element['src']
    
    # Status (Ongoing/Completed)
    status_element = entry.select_one('div.status')
    if status_element:
        manga['status'] = status_element.text.strip()
    
    # Titolo e link
    title_element = entry.select_one('h3.title a')
    if title_element:
        manga['title'] = title_element.text.strip()
        manga['url'] = title_element.get('href', '')
    
    # Ultimo capitolo
    chapter_element = entry.select_one('div.chapter a')
    if chapter_element:
        manga['latest_chapter'] = {
            'title': chapter_element.text.strip(),
            'url': chapter_element.get('href', '')
        }
    
    # Generi (dal data-genre attribute)
    parent_div = entry
    if parent_div.has_attr('data-genre'):
        manga['genre_ids'] = parent_div.get('data-genre', '')
    
    # ID manga (dal data-id attribute)
    if parent_div.has_attr('data-id'):
        manga['manga_id'] = parent_div.get('data-id', '')
    
    return manga

def mangaKatanaHotUpdatesExtraction(entry):
    """
    Estrazione specifica per il carousel Hot Updates di MangaKatana.
    Struttura HTML diversa rispetto alla lista principale.
    """
    manga = {}
    
    # Thumbnail
    thumb_element = entry.select_one('div.wrap_img img')
    if thumb_element and 'src' in thumb_element.attrs:
        manga['thumbnail'] = thumb_element['src']
    
    # Titolo e link
    title_element = entry.select_one('h3.title a')
    if title_element:
        manga['title'] = title_element.text.strip()
        manga['url'] = title_element.get('href', '')
    
    # Ultimo capitolo (rimuove l'icona se presente)
    chapter_element = entry.select_one('div.chapter a')
    if chapter_element:
        chapter_text = chapter_element.text.strip()
        # Rimuove il carattere dell'icona
        chapter_text = chapter_text.replace('', '').strip()
        manga['latest_chapter'] = {
            'title': chapter_text,
            'url': chapter_element.get('href', '')
        }
    
    # Generi (dal data-genre attribute)
    if entry.has_attr('data-genre'):
        manga['genre_ids'] = entry.get('data-genre', '')
    
    # ID manga (dal data-id attribute)
    if entry.has_attr('data-id'):
        manga['manga_id'] = entry.get('data-id', '')
    
    return manga

@app.route('/new_manga_releases')
def new_manga_releases():
    # Ottieni parametri opzionali dalla richiesta
    page = request.args.get('page', default=1, type=int)
    max_pages = request.args.get('max_pages', default=1, type=int)
    
    # Calcola direttamente il numero di pagine da elaborare
    end_page = page + max_pages
    all_manga = []
    
    # Itera sulle pagine specificate
    for page_num in range(page, end_page):
        print(f"Elaborazione pagina {page_num}")
        if page_num == 1:
            # Pagina principale
            page_url = 'https://www.mangaworld.cx/'
        else:
            # Pagine successive
            page_url = f'https://www.mangaworld.cx/?page={page_num}/'
        
        response = requests.get(page_url)
        
        if response.status_code == 200:
            soup = BeautifulSoup(response.content, 'html.parser')
            # Find the comics-grid container that holds the manga entries
            comics_grid = soup.find('div', {'class': 'comics-grid'})
            if comics_grid:
                manga_entries = comics_grid.find_all('div', {'class': 'entry'})
                for entry in manga_entries:
                    manga_info = mangaWorldExtraction(entry)
                    if manga_info:
                        all_manga.append(manga_info)
                    
    response_data = {
        "status": "ok",
        "messaggio": f"chiamata eseguita correttamente - new_manga_releases (pagine {page}-{end_page-1})",
        "pagina_corrente": page,
        "pagine_elaborate": max_pages,
        "totale_manga": len(all_manga),
        "data": all_manga,
    }
    return jsonify(response_data)

@app.route('/getMKlastRelease')
def getMKlastRelease():
    page = request.args.get('page', default=1, type=int)
    max_pages = request.args.get('max_pages', default=1, type=int)
    
    end_page = page + max_pages
    all_manga = []
    
    for page_num in range(page, end_page):
        print(f"Elaborazione pagina {page_num}")
        if page_num == 1:
            page_url = 'https://mangakatana.com/'
        else:
            page_url = f'https://mangakatana.com/page/{page_num}'
            
        response = requests.get(page_url)
        
        if response.status_code == 200:
            soup = BeautifulSoup(response.content, 'html.parser')
            book_list = soup.find('div', {'id': 'book_list'})
            if book_list:
                manga_entries = book_list.find_all('div', {'class': 'item'})
                print(f"Trovati {len(manga_entries)} manga nella pagina {page_num}")
                for entry in manga_entries:
                    manga_info = mangaKatanaExtraction(entry)
                    if manga_info:
                        all_manga.append(manga_info)
    
    response_data = {
        "status": "ok",
        "messaggio": f"chiamata eseguita correttamente - getMKlastRelease (pagine {page}-{end_page-1})",
        "pagina_corrente": page,
        "pagine_elaborate": max_pages,
        "totale_manga": len(all_manga),
        "data": all_manga
    }
    return jsonify(response_data)

@app.route('/search_manga')
def search_manga():
    keyword = request.args.get('keyword', '')
    response = requests.get('https://www.mangaworld.cx/archive?keyword=' + encode_keyword(keyword))
    result_list = []
    if response.status_code == 200:
        soup = BeautifulSoup(response.content, 'html.parser')
        manga_entries = soup.find_all('div', {'class': 'entry'})
        for entry in manga_entries:
            manga_info = mangaWorldExtraction(entry)
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
    html_content = request.args.get('html_content', '')
    result_list = []
    
    if html_content:
        # Parse provided HTML content directly
        soup = BeautifulSoup(html_content, 'html.parser')
        manga_entries = soup.find_all('div', {'class': 'entry'})
        
        for entry in manga_entries:
            # Extract manga title and URL
            title_elem = entry.find('h3', {'class': 'entry-title'})
            if title_elem:
                manga_link = title_elem.find('a')
                if manga_link:
                    manga_title = manga_link.get_text(strip=True)
                    manga_url = manga_link.get('href', '')
                    
                    # Find all chapter links within this entry
                    chapter_links = entry.find_all('a', {'class': 'chap'})
                    for chap_link in chapter_links:
                        link = chap_link.get('href', '')
                        alt = chap_link.get('title', '')
                        if "read" in link:
                            result_list.append({
                                'manga_title': manga_title,
                                'manga_url': manga_url,
                                'chapter_link': link,
                                'chapter_title': alt
                            })
    else:
        # Original behavior: make HTTP request
        response = requests.get(url)
        if response.status_code == 200:
            soup = BeautifulSoup(response.content, 'html.parser')
            Manga = soup.find_all('a', {'class': 'chap'})
            for item in Manga:
                link = re.search('href="(.+?)"', str(item)).group(1)
                alt = re.search('title="(.+?)"', str(item)).group(1)
                if "read" in link:
                    result_list.append({'link': link, 'alt': alt})
    result_list.reverse()
    
    # Cerca di estrarre informazioni manga dall'HTML se disponibile
    manga_info = None
    if html_content:
        soup = BeautifulSoup(html_content, 'html.parser')
        
        # Cerca prima il nuovo formato con meta-data
        meta_data_div = soup.find('div', class_='meta-data row px-1')
        if meta_data_div:
            manga_info = mangaWorldMetaExtraction(meta_data_div)
        else:
            # Fallback al vecchio formato
            # Cerca il contenitore con le informazioni del manga
            manga_info_div = soup.find('div', class_='has-shadow comic-info d-block d-sm-flex')
            if not manga_info_div:
                # Prova con un selettore più generico
                manga_info_div = soup.find('div', class_='comic-info')
            if manga_info_div:
                manga_info = mangaWorldExtraction(manga_info_div)
    
    # Se non abbiamo trovato le info manga nell'HTML e abbiamo un URL, facciamo una richiesta separata
    if not manga_info and url and not html_content:
        try:
            print(f"Tentativo di ottenere informazioni manga da: {url}")
            manga_response = requests.get(url)
            if manga_response.status_code == 200:
                manga_soup = BeautifulSoup(manga_response.content, 'html.parser')
                
                # Cerca prima il nuovo formato con meta-data
                meta_data_div = manga_soup.find('div', class_='meta-data row px-1')
                if meta_data_div:
                    manga_info = mangaWorldMetaExtraction(meta_data_div)
                    print(f"Informazioni manga estratte con nuovo formato: {len(manga_info)} campi")
                else:
                    # Fallback al vecchio formato
                    manga_info_div = manga_soup.find('div', class_='has-shadow comic-info d-block d-sm-flex')
                    if not manga_info_div:
                        manga_info_div = manga_soup.find('div', class_='comic-info')
                    if manga_info_div:
                        manga_info = mangaWorldExtraction(manga_info_div)
                        print(f"Informazioni manga estratte con vecchio formato: {len(manga_info)} campi")
        except Exception as e:
            print(f"Errore nell'estrazione delle informazioni manga: {str(e)}")
            manga_info = None
    
    # Prepara la risposta con le informazioni del manga e i capitoli
    response_data_content = {}
    if manga_info:
        # Aggiungi tutte le informazioni del manga direttamente all'oggetto principale
        response_data_content.update(manga_info)
    
    # Aggiungi i capitoli come chiave separata
    response_data_content['chapters'] = result_list
    
    response_data = {
        "status": "ok",
        "messaggio": f"chiamata eseguita correttamente - manga_chapters(link={url}, html_content={'provided' if html_content else 'not provided'})",
        "data": response_data_content
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
    urls_str = request.args.get('urls', '[]')

@app.route('/download_single_image')
def download_single_image():
    image_url = request.args.get('url', '')
    if not image_url:
        return jsonify({
            "status": "error",
            "messaggio": "Parametro 'url' mancante",
            "data": {}
        }), 400
    logger.info(f"Richiesta ricevuta per: {image_url}")
    try:
        response = requests.get(image_url, timeout=10)
        if response.status_code != 200:
            return jsonify({
                "status": "error",
                "messaggio": f"Immagine non trovata (HTTP {response.status_code})",
                "data": {}
            }), 404
        image_base64 = base64.b64encode(response.content).decode('utf-8')
        content_type = response.headers.get('Content-Type', 'image/jpeg')
        response_data = {
            "status": "ok",
            "messaggio": "Immagine scaricata correttamente",
            "data": {
                "url": image_url,
                "mime_type": content_type,
                "uint8list_base64": image_base64,
                "size_bytes": len(response.content)
            }
        }
        return jsonify(response_data)
    except Exception as e:
        logger.error(f"Errore durante il download: {str(e)}")
        return jsonify({
            "status": "error",
            "messaggio": f"Errore durante il download: {str(e)}",
            "data": {}
        }), 500

@app.route('/download_image')
def download_image():
    logger.info(f"Richiesta ricevuta con: {urls_str}")
    try:
        urls = json.loads(urls_str)
        if not isinstance(urls, list) or len(urls) == 0:
            return jsonify({
                "status": "error",
                "messaggio": "Parametro 'urls' deve essere una lista non vuota",
                "data": []
            }), 400
        MAX_URLS = 5000
        if len(urls) > MAX_URLS:
            urls = urls[:MAX_URLS]
            warning = f"Limite di {MAX_URLS} URL raggiunto. Solo i primi {MAX_URLS} URL sono stati processati."
            logger.warning(warning)
        else:
            warning = None
    except Exception as e:
        logger.error(f"Errore nel parsing degli URL: {str(e)}")
        return jsonify({
            "status": "error",
            "messaggio": f"Errore nel parsing degli URL: {str(e)}",
            "data": []
        }), 400
    results = []
    def download_single_image(image_url):
        try:
            response = requests.get(image_url, timeout=10)
            if response.status_code != 200:
                return {
                    "url": image_url,
                    "success": False,
                    "error": f"Immagine non trovata (HTTP {response.status_code})"
                }
            image_base64 = base64.b64encode(response.content).decode('utf-8')
            content_type = response.headers.get('Content-Type', 'image/jpeg')
            return {
                "url": image_url,
                "success": True,
                "mime_type": content_type,
                "uint8list_base64": image_base64,
                "size_bytes": len(response.content)
            }
        except Exception as e:
            return {
                "url": image_url,
                "success": False,
                "error": f"Errore durante il download: {str(e)}"
            }
    with ThreadPoolExecutor(max_workers=5) as executor:
        future_to_url = {executor.submit(download_single_image, url): url for url in urls}
        for future in as_completed(future_to_url):
            result = future.result()
            results.append(result)
    url_to_result = {result['url']: result for result in results}
    sorted_results = [url_to_result[url] for url in urls if url in url_to_result]
    response_data = {
        "status": "ok",
        "messaggio": "Download immagini completato",
        "data": {
            "total_urls": len(urls),
            "successful_downloads": sum(1 for r in sorted_results if r.get("success")),
            "results": sorted_results,
            "warning": warning if warning else None
        }
    }
    logger.info(f"Richiesta completata: {len(urls)} URL, {response_data['data']['successful_downloads']} successi")
    return jsonify(response_data)
    # Ottieni parametri opzionali dalla richiesta
    page = request.args.get('page', default=1, type=int)
    max_pages = request.args.get('max_pages', default=1, type=int)
    
    # Calcola direttamente il numero di pagine da elaborare
    end_page = page + max_pages
    all_manga = []
    
    # Itera sulle pagine specificate
    for page_num in range(page, end_page):
        print(f"Elaborazione pagina {page_num}")
        page_url = f'https://www.mangaworld.cx/archive?page={page_num}'
        page_response = requests.get(page_url)
        if page_response.status_code == 200:
            page_soup = BeautifulSoup(page_response.content, 'html.parser')
            manga_entries = page_soup.find_all('div', {'class': 'entry'})
            for entry in manga_entries:
                manga_info = mangaWorldExtraction(entry)
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
    Estrae i capitoli disponibili per una novel specifica da novelfire.net, gestendo la paginazione.
    """
    # Pulisci l'URL dagli spazi e caratteri non necessari
    raw_url = request.args.get('url', '')
    if not raw_url:
        return jsonify({
            "status": "error",
            "messaggio": "URL della novel non fornito",
            "data": []
        }), 400
    
    # Pulisci l'URL rimuovendo spazi, tab e altri caratteri bianchi
    url = raw_url.strip()
    
    print(f"Fetching chapters from (cleaned): {url}")
    
    # Assicurati che l'URL non abbia spazi alla fine
    url = url.rstrip()
    
    if not url.endswith('/'):
        url = f"{url}/"
        
    # Costruisci l'URL base per i capitoli
    if 'chapters' not in url:
        base_url = f"{url}chapters"
    else:
        base_url = url
    
    # Rimuovi eventuali parametri esistenti per evitare duplicati
    if '?' in base_url:
        base_url = base_url.split('?')[0]
    
    print(f"Base URL for chapters: {base_url}")
    
    try:
        # USIAMO CLOUDSCRAPER PER BYPASSARE LE PROTEZIONI CLOUDFLARE
        scraper = cloudscraper.create_scraper(
            browser={
                'browser': 'chrome',
                'platform': 'windows',
                'mobile': False
            },
            delay=10
        )
        
        all_chapters = []
        page = 1
        empty_pages_count = 0  # Contatore per pagine vuote consecutive
        max_empty_pages = 2    # Numero massimo di pagine vuote prima di fermarsi
        
        print("Starting pagination loop...")
        
        while empty_pages_count < max_empty_pages:
            # Costruisci l'URL per la pagina corrente
            page_url = f"{base_url}?page={page}"
            print(f"Requesting page {page}: {page_url}")
            
            response = scraper.get(page_url, timeout=15)
            
            # Forziamo l'encoding a utf-8
            response.encoding = 'utf-8'
            
            if response.status_code != 200:
                print(f"Errore nella richiesta HTTP per la pagina {page}: {response.status_code}")
                # Prova la prossima pagina, potrebbe essere un errore temporaneo
                page += 1
                time.sleep(1)
                continue
            
            # Analizza l'HTML
            soup = BeautifulSoup(response.text, 'html.parser')
            chapter_list_ul = soup.find('ul', class_='chapter-list')
            
            # Cerca anche con selettore CSS se il metodo find non funziona
            if not chapter_list_ul:
                chapter_list_ul = soup.select_one('ul.chapter-list')
            
            # Estrai i capitoli da questa pagina
            current_page_chapters = []
            
            if chapter_list_ul:
                for li in chapter_list_ul.find_all('li'):
                    a_tag = li.find('a')
                    if a_tag:
                        # Estrai il numero del capitolo
                        chapter_no = li.find('span', class_='chapter-no')
                        chapter_no = chapter_no.text.strip() if chapter_no else ""
                        
                        # Estrai il titolo
                        chapter_title = li.find('strong', class_='chapter-title')
                        chapter_title = chapter_title.text.strip() if chapter_title else ""
                        
                        # Estrai la data di aggiornamento
                        chapter_update = li.find('time', class_='chapter-update')
                        update_datetime = chapter_update.get('datetime', '') if chapter_update else ""
                        update_text = chapter_update.text.strip() if chapter_update else ""
                        
                        # Costruisci l'URL completo
                        href = a_tag['href']
                        if href.startswith('/'):
                            href = f"https://novelfire.net{href}"
                        
                        # Aggiungi il capitolo alla lista dei risultati
                        if href and chapter_title:
                            current_page_chapters.append({
                                'link': href,
                                'title': chapter_title,
                                'number': chapter_no,
                                'update_datetime': update_datetime,
                                'update_text': update_text
                            })
            
            # Verifica se abbiamo trovato capitoli
            if current_page_chapters:
                print(f"Found {len(current_page_chapters)} chapters on page {page}")
                all_chapters.extend(current_page_chapters)
                empty_pages_count = 0  # Reimposta il contatore di pagine vuote
            else:
                print(f"No chapters found on page {page}")
                empty_pages_count += 1
            
            # Passa alla prossima pagina
            page += 1
            
            # Aggiungi un piccolo ritardo per non sovraccaricare il server
            time.sleep(0.7)
        
        print(f"Pagination completed. Total pages checked: {page-1}, Total chapters found: {len(all_chapters)}")
        
        # Rimuovi duplicati (potrebbero esserci in casi rari)
        unique_chapters = []
        seen_urls = set()
        
        for chapter in all_chapters:
            if chapter['link'] not in seen_urls:
                seen_urls.add(chapter['link'])
                unique_chapters.append(chapter)
        
        print(f"Total unique chapters found: {len(unique_chapters)}")
        
        response_data = {
            "status": "ok",
            "messaggio": f"chiamata eseguita correttamente - get_novelfire_chapters(url={url})",
            "data": unique_chapters
        }
        
        return jsonify(response_data)
        
    except Exception as e:
        print(f"Errore durante l'estrazione dei capitoli: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({
            "status": "error",
            "messaggio": f"Errore durante l'estrazione dei capitoli: {str(e)}",
            "data": []
        }), 500
@app.route('/get_novelfire_chapter_content')
def get_novelfire_chapter_content():
    """
    Estrae il contenuto di un capitolo specifico da novelfire.net in una lingua specifica.
    Richiede l'URL del capitolo e la lingua come parametri.
    """
    # Pulisci l'URL dagli spazi e caratteri non necessari
    raw_url = request.args.get('url', '')
    if not raw_url:
        return jsonify({
            "status": "error",
            "messaggio": "URL del capitolo non fornito",
            "data": {}
        }), 400
    
    # Ottieni la lingua desiderata dal parametro (default: italiano)
    lang = request.args.get('lang', 'it').lower()
    
    # Pulisci l'URL rimuovendo spazi, tab e altri caratteri bianchi
    url = raw_url.strip().rstrip()
    
    print(f"Fetching chapter content in {lang} from (cleaned): {url}")
    
    try:
        # USIAMO CLOUDSCRAPER PER BYPASSARE LE PROTEZIONI CLOUDFLARE
        scraper = cloudscraper.create_scraper(
            browser={
                'browser': 'chrome',
                'platform': 'windows',
                'mobile': False
            },
            delay=10
        )
        
        response = scraper.get(url, timeout=15)
        
        # Forziamo l'encoding a utf-8
        response.encoding = 'utf-8'
        
        # Per debug: salva la risposta in un file
        with open('debug_chapter.html', 'w', encoding='utf-8') as f:
            f.write(response.text)
        
        if response.status_code != 200:
            print(f"Errore nella richiesta HTTP: {response.status_code}")
            return jsonify({
                "status": "error",
                "messaggio": f"Errore nella richiesta HTTP: {response.status_code}",
                "data": {}
            }), 500
        
        # Analizza l'HTML
        soup = BeautifulSoup(response.text, 'html.parser')
        
        # Estrai il div con classe "titles"
        titles_div = None
        
        # Prova diversi selettori per trovare il titolo
        possible_titles_divs = [
            soup.find('div', class_='titles'),
            soup.find('div', class_='chapter-header'),
            soup.find('section', class_='chapter-header'),
            soup.find('div', {'id': 'chapter-header'}),
            soup.find('h1', class_='chapter-title')
        ]
        
        for div in possible_titles_divs:
            if div:
                titles_div = div
                break
        
        titles_data = {}
        
        if titles_div:
            # Estrai il titolo del libro
            book_title_element = titles_div.find('a', class_='booktitle')
            if not book_title_element:
                # Prova con un selettore alternativo
                book_title_element = titles_div.find('a', itemprop='sameAs')
                if not book_title_element:
                    # Prova a trovare il titolo del libro in altri modi
                    h1 = soup.find('h1')
                    if h1:
                        # Cerca un link all'interno dell'h1
                        book_title_element = h1.find('a')
            
            book_title = book_title_element.get_text(strip=True) if book_title_element else ""
            
            # Estrai il titolo del capitolo
            chapter_title_element = titles_div.find('span', class_='chapter-title')
            if not chapter_title_element:
                chapter_title_element = titles_div.find('h1')
                if not chapter_title_element:
                    # Prova a trovare il titolo del capitolo in altri modi
                    chapter_title_element = soup.find('h1', class_='entry-title')
            
            chapter_title = chapter_title_element.get_text(strip=True) if chapter_title_element else ""
            
            # Estrai la data di pubblicazione
            date_published_meta = titles_div.find('meta', itemprop='datePublished')
            if not date_published_meta:
                date_published_meta = soup.find('meta', itemprop='datePublished')
            
            date_published = date_published_meta['content'] if date_published_meta else ""
            
            titles_data = {
                "book_title": book_title,
                "chapter_title": chapter_title,
                "date_published": date_published
            }
        else:
            print("ERRORE: Non trovato div.titles nella pagina")
            # Prova a estrarre i titoli in modo alternativo
            h1 = soup.find('h1')
            if h1:
                titles_data = {
                    "book_title": "N/A",
                    "chapter_title": h1.get_text(strip=True),
                    "date_published": ""
                }
        
        # Cerchiamo il contenuto del capitolo con diversi approcci
        content_div = None
        
        # 1. Cerca per id e classi comuni
        content_div = soup.find('div', {'id': 'content', 'class': 'clearfix font_default'})
        
        # 2. Cerca solo per id
        if not content_div:
            content_div = soup.find('div', id='content')
        
        # 3. Cerca per itemprop="description"
        if not content_div:
            content_div = soup.find('div', itemprop='description')
        
        # 4. Cerca per classi comuni
        if not content_div:
            common_classes = ['chapter-content', 'entry-content', 'content', 'post-content', 'main-content', 'novel-content']
            for class_name in common_classes:
                content_div = soup.find('div', class_=class_name)
                if content_div:
                    break
        
        # 5. Cerca div che contengono molti paragrafi
        if not content_div:
            # Trova tutti i div e ordina per numero di paragrafi
            all_divs = soup.find_all('div')
            divs_with_paragraphs = []
            
            for div in all_divs:
                paragraphs = div.find_all('p')
                if len(paragraphs) > 3:  # Considera solo div con più di 3 paragrafi
                    divs_with_paragraphs.append((div, len(paragraphs)))
            
            # Ordina per numero di paragrafi (decrescente)
            divs_with_paragraphs.sort(key=lambda x: x[1], reverse=True)
            
            if divs_with_paragraphs:
                content_div = divs_with_paragraphs[0][0]
        
        content_paragraphs = []
        
        if content_div:
            print("Div content trovato con successo!")
            
            # Estrai tutti i tag <p> all'interno del div content
            paragraphs = content_div.find_all('p')
            
            if paragraphs:
                print(f"Trovati {len(paragraphs)} paragrafi")
                
                for p in paragraphs:
                    # Estrai il testo in modo robusto, gestendo diversi formati
                    text = ""
                    
                    # 1. Prova a prendere il testo direttamente
                    text = p.get_text(strip=True)
                    
                    # 2. Se non c'è testo, cerca font o altri elementi
                    if not text:
                        for font in p.find_all('font'):
                            text += font.get_text(strip=True) + " "
                        text = text.strip()
                    
                    # 3. Se ancora non c'è testo, cerca span o altri elementi
                    if not text:
                        for span in p.find_all('span'):
                            text += span.get_text(strip=True) + " "
                        text = text.strip()
                    
                    # 4. Se c'è testo, aggiungilo alla lista
                    if text:
                        content_paragraphs.append(text)
            else:
                print("Nessun tag <p> trovato, provo a estrarre il testo in altro modo")
                
                # Estrai il testo direttamente dal div content
                text = content_div.get_text(separator='\n\n', strip=True)
                if text:
                    # Dividi il testo in paragrafi
                    paragraphs = [p.strip() for p in text.split('\n\n') if p.strip()]
                    content_paragraphs.extend(paragraphs)
        else:
            print("ERRORE: Non trovato div#content nella pagina")
            # Per debug: stampa una porzione dell'HTML per verificare cosa c'è nella pagina
            print("Primi 1000 caratteri dell'HTML ricevuto:")
            print(response.text[:1000])
        
        # Costruisci la risposta
        response_data = {
            "status": "ok",
            "messaggio": f"Contenuto del capitolo estratto correttamente (url={url}, lang={lang})",
            "data": {
                "titles": titles_data,
                "content": content_paragraphs
            }
        }
        
        print(f"Totale paragrafi estratti: {len(content_paragraphs)}")
        
        return jsonify(response_data)
        
    except Exception as e:
        print(f"Errore durante l'estrazione del contenuto del capitolo: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({
            "status": "error",
            "messaggio": f"Errore durante l'estrazione del contenuto del capitolo: {str(e)}",
            "data": {}
        }), 500

if __name__ == '__main__':
    import ssl
    import os
    
    # Configurazione HTTPS
    use_https = os.getenv('FLASK_HTTPS', 'false').lower() == 'true'
    
    if use_https:
        # Crea certificati auto-firmati se non esistono
        cert_file = 'server.crt'
        key_file = 'server.key'
        
        if not os.path.exists(cert_file) or not os.path.exists(key_file):
            print("Creazione certificati auto-firmati...")
            os.system(f"""
openssl req -x509 -newkey rsa:4096 -keyout {key_file} -out {cert_file} -days 365 -nodes -subj '/C=IT/ST=Italy/L=Rome/O=MangaReader/CN=localhost'
            """)
        
        # Crea contesto SSL
        context = ssl.SSLContext(ssl.PROTOCOL_TLSv1_2)
        context.load_cert_chain(cert_file, key_file)
        
        print("Avvio server HTTPS su https://localhost:8000")
        app.run(host='0.0.0.0', port=8000, debug=True, ssl_context=context)
    else:
        print("Avvio server HTTP su http://localhost:8000")
        app.run(host='0.0.0.0', port=8000, debug=True)
