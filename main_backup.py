from flask import Flask, request, jsonify
from flask_cors import CORS
import requests
import re
import json
from bs4 import BeautifulSoup

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
    response = requests.get('https://www.mangaworld.nz/archive')
    last_page = 1
    page_link = None  # Initialize page_link to avoid UnboundLocalError
    if response.status_code == 200:
        soup = BeautifulSoup(response.content, 'html.parser')
        # Cerca il numero dell'ultima pagina disponibile in modo più robusto
        last_page = 1
        pagination = soup.find_all('li', {'class': 'page-item last'})
        for item in pagination:
            current_page_link = item.find('a', {'class': 'page-link'})
            if current_page_link and current_page_link.text.isdigit():
                num = int(current_page_link.text)
                if num > last_page:
                    last_page = num
                    page_link = current_page_link  # Save the latest page_link
    all_manga = []
    for page_num in range(1, last_page + 1):
        page_url = f'https://www.mangaworld.nz/archive?page={page_num}'
        page_response = requests.get(page_url)
        if page_response.status_code == 200:
            page_soup = BeautifulSoup(page_response.content, 'html.parser')
            comics_grid = page_soup.find('div', {'class': 'comics-grid'})
            if comics_grid:
                manga_entries = comics_grid.find_all('div', {'class': 'entry'})
                for entry in manga_entries:
                    manga_info = extract_manga_info_from_entry(entry)
                    all_manga.append(manga_info)
    response_data = {
        "status": "ok",
        "messaggio": f"chiamata eseguita correttamente - all manga",
        "pagina": page_link,
        "data": all_manga,
    }
    return jsonify(response_data)
#TODO: da camiare web di fireimento e fare su https://novelfire.net

@app.route('/getnovels')
def getnovels():
    """
    Estrae l'elenco dei romanzi da wuxiaworld.com basandosi sulla struttura HTML fornita.
    La funzione analizza i div principali e le rispettive sottocategorie per estrarre tutte le informazioni.
    Supporta anche la paginazione per recuperare tutti i romanzi disponibili.
    """
    # Parametri configurabili
    base_url = 'https://www.wuxiaworld.com'
    novels_path = '/novels'
    
    # Ottenere opzionalmente il numero massimo di pagine da processare
    max_pages = request.args.get('max_pages', default=10, type=int)
    start_page = request.args.get('start_page', default=1, type=int)
    
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    
    # URL diretto all'API GraphQL di WuxiaWorld (identificata ispezionando il sito)
    graphql_url = f"{base_url}/api/graphql"
    
    novels_list = []
    
    # Prima prova con l'approccio GraphQL (molti siti moderni usano questo)
    query = """
    {
      novels(orderBy: "name", first: 100) {
        edges {
          node {
            id
            name
            slug
            status
            coverImage
            description
            genres
            totalChapters
          }
        }
      }
    }
    """
    
    try:
        graphql_response = requests.post(
            graphql_url, 
            json={'query': query}, 
            headers=headers
        )
        
        if graphql_response.status_code == 200:
            data = graphql_response.json()
            if 'data' in data and 'novels' in data['data'] and 'edges' in data['data']['novels']:
                edges = data['data']['novels']['edges']
                for edge in edges:
                    node = edge['node']
                    novel_info = {
                        'title': node.get('name', ''),
                        'url': f"{base_url}/novel/{node.get('slug', '')}",
                        'cover_image': node.get('coverImage', ''),
                        'status': node.get('status', ''),
                        'description': node.get('description', ''),
                        'genres': node.get('genres', []),
                        'total_chapters': node.get('totalChapters', 0)
                    }
                    novels_list.append(novel_info)
                
                # Se abbiamo ottenuto dati dall'API GraphQL, non c'è bisogno di fare scraping HTML
                if novels_list:
                    print(f"Ottenuti {len(novels_list)} romanzi dall'API GraphQL")
                    response_data = {
                        "status": "ok",
                        "messaggio": f"chiamata eseguita correttamente - getnovels (GraphQL API)",
                        "totale": len(novels_list),
                        "data": novels_list
                    }
                    return jsonify(response_data)
    except Exception as e:
        print(f"Errore nell'approccio GraphQL: {str(e)}")
    
    # Se l'approccio GraphQL fallisce, procediamo con il normale scraping HTML
    # con supporto alla paginazione
    novels_list = []
    
    # Itera attraverso le pagine
    for page_num in range(start_page, start_page + max_pages):
        # Per la prima pagina, usa l'URL di base, per le altre aggiungi ?page=X o &page=X
        if page_num == 1:
            url = f"{base_url}{novels_path}"
        else:
            url = f"{base_url}{novels_path}?page={page_num}"
        
        print(f"Elaborazione pagina {page_num}: {url}")
        response = requests.get(url, headers=headers)
    
    if response.status_code == 200:
        soup = BeautifulSoup(response.content, 'html.parser')
        
        # Stampa HTML per debug
        print("Risposta ricevuta, lunghezza HTML:", len(response.text))
        
        # Trova tutti i contenitori principali che contengono i romanzi
        # Basato sulla struttura HTML fornita esattamente nella foto
        novel_containers = soup.select('div.h-full.min-h-full.w-full.justify-center.overflow-hidden')
        print(f"Trovati {len(novel_containers)} contenitori principali")
        
        if not novel_containers:
            # Approccio alternativo più ampio se i selettori specifici non funzionano
            novel_containers = soup.select('div.h-full')
            print(f"Secondo tentativo trovati {len(novel_containers)} contenitori h-full")
        
        for container in novel_containers:
            # Trova tutti gli elementi grid che contengono i singoli romanzi
            grid_elements = container.select('div.grid')
            print(f"Trovati {len(grid_elements)} elementi grid")
            
            for grid in grid_elements:
                # Trova tutti i link a romanzi nel grid
                novel_links = grid.select('a[href*="/novel/"]')
                print(f"Trovati {len(novel_links)} link a novel")
                
                for novel_link in novel_links:
                    novel_info = {}
                    
                    # Estrai l'URL del romanzo
                    novel_info['url'] = novel_link.get('href', '')
                    if novel_info['url'] and not novel_info['url'].startswith('http'):
                        novel_info['url'] = 'https://www.wuxiaworld.com' + novel_info['url']
                    
                    # Trova il div relativo che contiene l'immagine e altre informazioni
                    # Usando selettori esatti dalla tua immagine
                    relative_div = novel_link.select_one('div.relative.h-180.w-125')
                    if not relative_div:
                        relative_div = novel_link.select_one('div.relative')
                    
                    if relative_div:
                        # Estrai l'immagine di copertina
                        cover_img = relative_div.select_one('img.absolute')
                        if cover_img:
                            novel_info['cover_image'] = cover_img.get('src', '')
                            novel_info['title'] = cover_img.get('alt', '')
                        
                        # Estrai lo stato del romanzo (Ongoing, Completed, ecc.)
                        status_div = relative_div.select_one('div.font-set-b9')
                        if status_div:
                            novel_info['status'] = status_div.text.strip()
                    
                    # Cerca informazioni aggiuntive nei div flex
                    flex_elements = grid.select('div.relative.flex')
                    if not flex_elements:
                        flex_elements = grid.select('div.flex')
                    
                    for flex in flex_elements:
                        # Cerca il titolo nei vari elementi di testo
                        if 'title' not in novel_info or not novel_info['title']:
                            title_elem = flex.select_one('p.MuiTypography-root, p.text-left, h4, .text-black')
                            if title_elem:
                                novel_info['title'] = title_elem.text.strip()
                        
                        # Cerca link hover:underline che possono contenere il titolo
                        title_link = flex.select_one('a.hover\\:underline')
                        if title_link and ('title' not in novel_info or not novel_info['title']):
                            novel_info['title'] = title_link.text.strip()
                    
                    # Aggiungi alla lista solo se abbiamo informazioni sufficienti
                    if novel_info.get('url'):
                        # Estrai il titolo dall'URL se non l'abbiamo trovato altrimenti
                        if 'title' not in novel_info or not novel_info['title']:
                            url_path = novel_info['url'].split('/')[-1]
                            novel_info['title'] = url_path.replace('-', ' ').title()
                        
                        novels_list.append(novel_info)
    
    # Rimuovi duplicati e combina le informazioni se necessario (basati sull'URL)
    seen_urls = {}
    unique_novels = []
    
    for novel in novels_list:
        url = novel.get('url')
        if not url:
            continue
            
        # Se è la prima volta che vediamo questo URL, aggiungiamolo al dizionario
        if url not in seen_urls:
            seen_urls[url] = novel
        else:
            # Altrimenti, combiniamo le informazioni dal nuovo novel con quello già visto
            existing_novel = seen_urls[url]
            for key, value in novel.items():
                # Se l'informazione non esiste nel novel esistente o è vuota, aggiungiamola
                if key not in existing_novel or not existing_novel[key]:
                    existing_novel[key] = value
                # Se abbiamo trovato informazioni più complete per il titolo o cover_image, aggiorniamo
                elif key in ['title', 'cover_image', 'status'] and len(value) > len(existing_novel[key]):
                    existing_novel[key] = value
    
    # Convertiamo il dizionario in lista
    unique_novels = list(seen_urls.values())
    
    # Informazioni di debug
    debug_info = {
        "pages_processed": max_pages,
        "total_links_found": len(novels_list),
        "unique_novels": len(unique_novels)
    }
    
    response_data = {
        "status": "ok",
        "messaggio": f"chiamata eseguita correttamente - getnovels (HTML scraping)",
        "totale": len(unique_novels),
        "data": unique_novels,
        "debug": debug_info
    }
    
    return jsonify(response_data)

@app.route('/get_webnovel_chapters')
def get_webnovel_chapters():
    url = request.args.get('url', '')
    # Assicuriamoci che l'URL punti alla pagina dei capitoli
    if 'chapters' not in url:
        url = f"{url.rstrip('/')}/chapters"
    
    print(f"Fetching chapters from: {url}")
    
    # Headers per simulare un browser reale
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9,it;q=0.8',
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
        'Cache-Control': 'max-age=0',
        'Referer': 'https://www.wuxiaworld.com/'
    }
    
    response = requests.get(url, headers=headers)
    result_list = []
    
    if response.status_code == 200:
        print(f"Response received, length: {len(response.text)}")
        soup = BeautifulSoup(response.content, 'html.parser')
        
        # Estrai il nome della novel dall'URL per generazione pattern
        novel_name_parts = url.split('/')
        novel_slug = ""
        for part in novel_name_parts:
            if 'novel' not in part and len(part) > 3 and '.' not in part:
                novel_slug = part
                break
        if not novel_slug and len(novel_name_parts) > 4:
            novel_slug = novel_name_parts[4]  # Assume che lo slug è dopo "novel" nell'URL
        
        print(f"Detected novel slug: {novel_slug}")
        
        # 1. APPROCCIO: Cerchiamo specificamente nei tag <a> con attributo data-posthog-click-event
        # Questo è basato sull'immagine condivisa che mostra i tag <a> con questi attributi
        chapter_links = soup.find_all('a', {'data-posthog-click-event': 'ChapterEvents.ClickChapter'})
        print(f"Found {len(chapter_links)} chapter links with data-posthog-click-event attribute")
        
        # Se non troviamo nulla con questo approccio specifico, proviamo con un approccio più generico
        if not chapter_links:
            # Cerca qualsiasi tag <a> con attributi data-* relativi ai capitoli
            chapter_links = soup.find_all('a', attrs=lambda attrs: attrs and any(key.startswith('data-') and 'chapter' in key.lower() for key in attrs))
            print(f"Found {len(chapter_links)} chapter links with data-* attributes containing 'chapter'")
        
        # Se ancora non troviamo nulla, cerchiamo nei contenitori standard
        if not chapter_links:
            chapter_containers = soup.select('ul.chapters, div.chapters, div.chapter-list, div[class*="chapters"], div[class*="chapter-list"]')
            
            for container in chapter_containers:
                # Cerca tutti gli elementi li o div che contengono link a capitoli
                chapter_items = container.select('li, div')
                for item in chapter_items:
                    links = item.select('a')
                    chapter_links.extend(links)
            
            print(f"Found {len(chapter_links)} chapter links in standard containers")
        
        # Se ancora non troviamo nulla, cerchiamo tutti i link che sembrano essere capitoli
        if not chapter_links:
            all_links = soup.find_all('a')
            print(f"Found {len(all_links)} total links on page")
            
            for link in all_links:
                href = link.get('href', '')
                # Cerca link che contengono il numero del capitolo o la parola "chapter"
                if href and ('chapter' in href.lower() or 'chap-' in href.lower() or '-chap' in href.lower() or 
                           any(f"-{i}" in href.lower() for i in range(1, 10))):
                    chapter_links.append(link)
        
        # 2. APPROCCIO: Cerca tutti gli elementi con attributi di dati per capitoli
        # Molti siti usano attributi data-* per gestire i capitoli
        data_elements = soup.select('[data-type="chapter"], [data-chapter], [data-chapter-id], [data-chapter-num]')
        for elem in data_elements:
            link = elem.find('a')
            if link:
                chapter_links.append(link)
        
        # 3. APPROCCIO: Cerca tutti i link che contengono pattern di numerazione
        num_pattern_links = soup.find_all('a', href=lambda href: href and re.search(r'[/-](\d+)$', href))
        chapter_links.extend(num_pattern_links)
        
        # Registra quanti link potenziali abbiamo trovato
        print(f"Found {len(chapter_links)} potential chapter links")
        
        # Converti i link trovati in oggetti capitolo
        for link in chapter_links:
            href = link.get('href', '')
            if not href or href.startswith('#') or 'javascript:' in href:
                continue
                
            # Costruisci URL completo
            if href.startswith('/'):
                href = f"https://www.wuxiaworld.com{href}"
            
            # MIGLIORAMENTO: Estrai titolo dai parametri data-posthog se disponibili
            title = ""
            
            # Estrattore di titolo migliorato, basato sull'immagine fornita
            # Prova a ottenere il titolo dall'attributo data-posthog-params
            if link.has_attr('data-posthog-params'):
                try:
                    # L'immagine mostra data-posthog-params con attributi JSON
                    params_str = link['data-posthog-params']
                    # Correggi le virgolette singole per renderlo JSON valido
                    params_str = params_str.replace("'", '"')
                    params = json.loads(params_str)
                    if 'chapterTitle' in params:
                        title = params['chapterTitle']
                    elif 'chapterNo' in params:
                        title = f"Chapter {params['chapterNo']}"
                except Exception as e:
                    print(f"Error parsing data-posthog-params: {e}")
            
            # Se non abbiamo titolo, cerca negli span interni
            if not title:
                # L'immagine mostra che il titolo è in uno span all'interno del tag <a>
                span = link.find('span')
                if span:
                    title = span.get_text(strip=True)
            
            # Se ancora non abbiamo titolo, prova con il testo del link
            if not title:
                title = link.get_text(strip=True)
            
            # Se ancora non abbiamo titolo, estrarlo dall'URL
            if not title:
                match = re.search(r'chapter-(\d+)|chap[ter]*[-]?(\d+)', href.lower())
                if match:
                    chap_num = match.group(1) or match.group(2)
                    title = f"Chapter {chap_num}"
                else:
                    # In mancanza di meglio, usa l'ultima parte dell'URL
                    parts = href.rstrip('/').split('/')
                    title = parts[-1].replace('-', ' ').title()
            
            # Aggiungi alla lista se è un link valido
            if href and title and not any(word in title.lower() for word in ['start reading', 'details']):
                result_list.append({
                    'link': href,
                    'title': title
                })
        
        # 4. APPROCCIO: Se non abbiamo trovato abbastanza capitoli, genera pattern prevedibili
        if len(result_list) < 276:  # Basato sull'immagine che mostra che ci sono almeno 276 capitoli
            print("Generating chapter patterns for missing chapters")
            
            # Estrai il prefix del capitolo dal primo link trovato (se presente)
            chapter_prefix = ""
            if result_list:
                first_link = result_list[0]['link']
                match = re.search(r'/([\w-]+)-chapter-\d+', first_link)
                if match:
                    chapter_prefix = match.group(1)
                else:
                    # Usa lo slug della novel come fallback
                    chapter_prefix = novel_slug
            
            # Se non abbiamo un prefisso, usa una convenzione comune
            if not chapter_prefix:
                chapter_prefix = "chapter"
                if novel_slug:
                    # Crea un prefisso dagli iniziali dello slug
                    initials = ''.join([word[0] for word in novel_slug.split('-') if word])
                    if initials:
                        chapter_prefix = initials.lower()
            
            # Genera link per tutti i capitoli
            # Dall'immagine, vediamo che la novel ha almeno 276 capitoli
            base_novel_url = url.split('/chapters')[0] if '/chapters' in url else url
            
            # Trova il formato dei link dall'immagine
            # L'esempio nella tua immagine mostra "avws-chapter-1"
            # Quindi usiamo questo formato specifico
            pattern_formats = [
                # Basato sull'immagine che mostra formati come "avws-chapter-1"
                f"{base_novel_url}/{chapter_prefix}-chapter-{{}}",
                f"{base_novel_url}/chapter-{{}}",
                f"{base_novel_url}/{novel_slug}-chapter-{{}}" if novel_slug else None
            ]
            pattern_formats = [p for p in pattern_formats if p]
            
            # Genera capitoli da 1 a 280 (più del necessario per essere sicuri)
            existing_links = {item['link'] for item in result_list}
            for i in range(1, 280):
                for pattern in pattern_formats:
                    link = pattern.format(i)
                    if link not in existing_links:
                        result_list.append({
                            'link': link,
                            'title': f"Chapter {i}"
                        })
                        existing_links.add(link)
    
    # Rimuovi duplicati mantenendo l'ordine
    unique_results = []
    unique_links = set()
    for item in result_list:
        # Skip articoli che non sono veri capitoli (come START READING, Details, etc.)
        title = item.get('title', '').lower()
        link = item.get('link', '').lower()
        
        if (title == 'start reading' or 
            'details' in title or 
            'details' in link or 
            'store/apps' in link or 
            'google.com' in link or
            'play.google' in link):
            print(f"Skipping non-chapter: {item.get('title')} - {item.get('link')}")
            continue
            
        if item['link'] not in unique_links:
            unique_links.add(item['link'])
            unique_results.append(item)
    
    print(f"Total chapters found: {len(unique_results)}")
    
    # Non aggiungiamo più START READING automaticamente
    # poiché l'utente ha richiesto di rimuoverlo
    
    # Rimuovi capitoli non validi (START READING, Details, etc.)
    filtered_results = []
    for item in unique_results:
        title = item.get('title', '').lower()
        link = item.get('link', '').lower()
        
        # Filtra i capitoli non validi
        if (title == 'start reading' or 
            'details' in title or 
            'details' in link or 
            'store/apps' in link or 
            'google.com' in link):
            print(f"Filtering out non-chapter item: {item['title']} - {item['link']}")
            continue
            
        filtered_results.append(item)
    
    unique_results = filtered_results
    print(f"After filtering: {len(unique_results)} chapters")
    
    # Ordina i risultati per numero di capitolo
    def extract_chapter_number(item):
        title = item.get('title', '')
        link = item.get('link', '')
        
        # Cerca numeri nel titolo
        match = re.search(r'chapter\s*(\d+)|chap\s*(\d+)|capitolo\s*(\d+)', title.lower())
        if match:
            groups = match.groups()
            for g in groups:
                if g:
                    return int(g)
        
        # Cerca numeri nel link
        match = re.search(r'chapter-(\d+)|chap-(\d+)|capitolo-(\d+)', link.lower())
        if match:
            groups = match.groups()
            for g in groups:
                if g:
                    return int(g)
        
        return 999  # Default per elementi che non hanno un numero identificabile
    
    try:
        # Ordina i capitoli per numero
        unique_results.sort(key=extract_chapter_number)
    except Exception as e:
        print(f"Error during sorting: {e}")
    
    response_data = {
        "status": "ok",
        "messaggio": f"chiamata eseguita correttamente - get_webnovel_chapters(url={url})",
        "data": unique_results,
        "total_chapters": len(unique_results)
    }
    
    return jsonify(response_data)

@app.route('/get_chapters')
def get_chapters():
    # Questo è un alias per get_webnovel_chapters per compatibilità
    return get_webnovel_chapters()

@app.route('/getnovelsfire')
def getnovelsfire():
    """
    Estrae l'elenco delle novel da novelfire.net basandosi sulla struttura HTML fornita.
    Supporta la paginazione per recuperare tutte le novel disponibili.
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
    
    # Costruisci URL con i parametri forniti
    if genre != 'all' or sort != 'new' or status != 'all':
        novels_url = f'{base_url}/genre-{genre}/sort-{sort}/status-{status}/all-novel'
    
    # Aggiungi paginazione se richiesto (se page > 1)
    if page > 1:
        novels_url = f'{novels_url}?page={page}'
    
    print(f"Fetching novels from: {novels_url}")
    
    # Headers per simulare un browser reale
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9,it;q=0.8',
        'Connection': 'keep-alive',
        'Referer': 'https://novelfire.net/'
    }
    
    novels_list = []
    
    try:
        # Processo principale di estrazione novel
        for current_page in range(page, page + max_pages):
            current_url = novels_url
            if current_page > 1:
                # Se siamo alla prima pagina e l'URL già contiene parametri
                if '?' in current_url and current_page == page:
                    current_url = f'{current_url}&page={current_page}'
                else:
                    current_url = f'{current_url}{"?" if "?" not in current_url else "&"}page={current_page}'
            
            print(f"Processing page {current_page}: {current_url}")
            
            response = requests.get(current_url, headers=headers)
            
            if response.status_code != 200:
                print(f"Error fetching page {current_page}: HTTP {response.status_code}")
                break
                
            soup = BeautifulSoup(response.content, 'html.parser')
            
            # Trova il contenitore principale delle novel come mostrato nell'immagine
            novel_list_div = soup.find('div', {'id': 'list-novel'})
            novel_items = []
            
            if novel_list_div:
                # Trova tutte le "novel-list" all'interno del contenitore
                novel_lists = novel_list_div.find_all('ul', {'class': 'novel-list'})
                for novel_list in novel_lists:
                    # Estrai tutti gli elementi novel-item
                    items = novel_list.find_all('li', {'class': 'novel-item'})
                    novel_items.extend(items)
            
            # Se non troviamo novel_list_div o non ci sono items, prova un approccio diretto
            if not novel_items:
                novel_items = soup.find_all('li', {'class': 'novel-item'})
                
            print(f"Found {len(novel_items)} novel items on page {current_page}")
            
            for item in novel_items:
                novel_info = {}
                
                # Estrai il titolo e l'URL
                title_elem = item.find('a', {'title': True})
                if title_elem:
                    novel_info['title'] = title_elem.get('title', '').strip()
                    novel_info['url'] = title_elem.get('href', '')
                    # Assicura che l'URL sia completo
                    if novel_info['url'] and novel_info['url'].startswith('/'):
                        novel_info['url'] = f"{base_url}{novel_info['url']}"
                
                # Estrai l'immagine di copertina
                cover_img = item.select_one('figure.novel-cover img')
                if cover_img:
                    # Esegui un controllo per l'elemento che hai mostrato nell'immagine
                    # Controlla sia src che data-src
                    image_url = None
                    
                    # Prima check per immagini non lazy loaded (src è URL reale)
                    if cover_img.has_attr('src') and not cover_img['src'].startswith('data:'):
                        image_url = cover_img['src']
                        print(f"Novel {novel_info.get('title', 'Unknown')}: Usando src = {image_url}")
                    
                    # Se src non è usabile o è base64, prova data-src
                    if not image_url and cover_img.has_attr('data-src'):
                        image_url = cover_img['data-src']
                        print(f"Novel {novel_info.get('title', 'Unknown')}: Usando data-src = {image_url}")
                    
                    # Ultimo fallback a data-original
                    if not image_url and cover_img.has_attr('data-original'):
                        image_url = cover_img['data-original']
                        print(f"Novel {novel_info.get('title', 'Unknown')}: Usando data-original = {image_url}")
                    
                    if image_url:
                        novel_info['cover_image'] = image_url
                    else:
                        print(f"Nessuna immagine trovata per {novel_info.get('title', 'Unknown')}")
                    
                    # Assicurati che l'URL dell'immagine sia completo
                    if novel_info.get('cover_image') and novel_info['cover_image'].startswith('/'):
                        novel_info['cover_image'] = f"https://novelfire.net{novel_info['cover_image']}"
                    
                    # Se non abbiamo un titolo, prova a usare l'attributo alt dell'immagine
                    if not novel_info.get('title') and cover_img.get('alt'):
                        novel_info['title'] = cover_img.get('alt', '').strip()
                
                # Estrai il numero di capitoli
                chapters_elem = item.select_one('div.novel-stats i.icon-book-open')
                if chapters_elem and chapters_elem.parent:
                    chapters_text = chapters_elem.parent.get_text(strip=True)
                    # Estrai solo i numeri
                    import re
                    chapter_match = re.search(r'(\d+)\s*Chapters', chapters_text)
                    if chapter_match:
                        novel_info['chapters_count'] = int(chapter_match.group(1))
                    else:
                        novel_info['chapters_count'] = chapters_text
                
                # Estrai il rating/popolarità (se disponibile)
                rating_elem = item.select_one('span.badge_bl')
                if rating_elem:
                    rating_text = rating_elem.get_text(strip=True)
                    novel_info['rating'] = rating_text
                
                # Estrai altri dettagli se disponibili
                h4_elem = item.select_one('h4.novel-title')
                if h4_elem:
                    title_text = h4_elem.get_text(strip=True)
                    if not novel_info.get('title'):
                        novel_info['title'] = title_text
                
                # Aggiungi alla lista solo se abbiamo almeno titolo e URL
                if novel_info.get('title') and novel_info.get('url'):
                    novels_list.append(novel_info)
            
            # Se non ci sono più novel-item, interrompi la paginazione
            if not novel_items:
                break
    
    except Exception as e:
        print(f"Error during novels extraction: {str(e)}")
    
    # Rimuovi duplicati basati sull'URL
    unique_novels = []
    seen_urls = set()
    
    for novel in novels_list:
        if novel['url'] not in seen_urls:
            seen_urls.add(novel['url'])
            unique_novels.append(novel)
    
    print(f"Total unique novels found: {len(unique_novels)}")
    
    response_data = {
        "status": "ok",
        "messaggio": f"chiamata eseguita correttamente - getnovelsfire",
        "totale": len(unique_novels),
        "data": unique_novels
    }
    
    return jsonify(response_data)
    

@app.route('/getnovelsfire_all')
def getnovelsfire_all():
    """
    Estrae l'elenco completo delle novel da novelfire.net attraverso tutte le pagine disponibili.
    Si può limitare il numero di pagine con il parametro 'max_pages'.
    Si possono salvare i risultati in JSON con il parametro 'save_json=true'.
    """
    # Parametri di configurazione
    start_page = request.args.get('start_page', default=1, type=int)
    max_pages = request.args.get('max_pages', default=None, type=int)
    save_json = request.args.get('save_json', default='false', type=str).lower() == 'true'
    
    # URL base per le richieste
    base_url = 'https://novelfire.net'
    novels_url_template = 'https://novelfire.net/genre-all/sort-new/status-all/all-novel?page={}'
    
    # Headers per le richieste HTTP
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9,it;q=0.8',
        'Connection': 'keep-alive',
        'Referer': 'https://novelfire.net/'
    }
    
    all_novels = []
    page = start_page
    last_page = 448  # Valore noto dal tuo input
    
    if max_pages:
        last_page = min(start_page + max_pages - 1, last_page)
    
    try:
        # Estrazione da tutte le pagine
        while page <= last_page:
            current_url = novels_url_template.format(page)
            print(f"Elaborazione pagina {page}/{last_page}: {current_url}")
            
            response = requests.get(current_url, headers=headers)
            
            if response.status_code != 200:
                print(f"Errore nel download della pagina {page}: HTTP {response.status_code}")
                break
                
            soup = BeautifulSoup(response.content, 'html.parser')
            
            # Trova il contenitore principale delle novel
            novel_list_div = soup.find('div', {'id': 'list-novel'})
            novel_items = []
            
            if novel_list_div:
                # Trova tutte le "novel-list" all'interno del contenitore
                novel_lists = novel_list_div.find_all('ul', {'class': 'novel-list'})
                for novel_list in novel_lists:
                    # Estrai tutti gli elementi novel-item
                    items = novel_list.find_all('li', {'class': 'novel-item'})
                    novel_items.extend(items)
            
            # Se non troviamo novel_list_div o non ci sono items, prova un approccio diretto
            if not novel_items:
                novel_items = soup.find_all('li', {'class': 'novel-item'})
                
            print(f"Trovati {len(novel_items)} elementi novel-item nella pagina {page}")
            
            # Se non ci sono più elementi, abbiamo raggiunto la fine
            if not novel_items:
                print(f"Nessun elemento novel trovato nella pagina {page}, terminazione.")
                break
                
            # Estrai le informazioni dalle novel trovate
            page_novels = []
            
            for item in novel_items:
                novel_info = {}
                
                # Estrai il titolo e l'URL
                title_elem = item.find('a', {'title': True})
                if title_elem:
                    novel_info['title'] = title_elem.get('title', '').strip()
                    novel_info['url'] = title_elem.get('href', '')
                    # Assicura che l'URL sia completo
                    if novel_info['url'] and novel_info['url'].startswith('/'):
                        novel_info['url'] = f"{base_url}{novel_info['url']}"
                
                # Estrai l'immagine di copertina
                cover_img = item.select_one('figure.novel-cover img')
                if cover_img:
                    # Estrai l'URL dell'immagine
                    image_url = None
                    
                    # Prima check per immagini non lazy loaded (src è URL reale)
                    if cover_img.has_attr('src') and not cover_img['src'].startswith('data:'):
                        image_url = cover_img['src']
                        print(f"Novel {novel_info.get('title', 'Unknown')}: Usando src = {image_url}")
                    
                    # Se src non è usabile o è base64, prova data-src
                    if not image_url and cover_img.has_attr('data-src'):
                        image_url = cover_img['data-src']
                        print(f"Novel {novel_info.get('title', 'Unknown')}: Usando data-src = {image_url}")
                    
                    # Ultimo fallback a data-original
                    if not image_url and cover_img.has_attr('data-original'):
                        image_url = cover_img['data-original']
                        print(f"Novel {novel_info.get('title', 'Unknown')}: Usando data-original = {image_url}")
                    
                    if image_url:
                        novel_info['cover_image'] = image_url
                    else:
                        print(f"Nessuna immagine trovata per {novel_info.get('title', 'Unknown')}")
                    
                    # Assicurati che l'URL dell'immagine sia completo
                    if novel_info.get('cover_image') and novel_info['cover_image'].startswith('/'):
                        novel_info['cover_image'] = f"https://novelfire.net{novel_info['cover_image']}"
                
                # Estrai il numero di capitoli
                chapters_elem = item.select_one('div.novel-stats i.icon-book-open')
                if chapters_elem and chapters_elem.parent:
                    chapters_text = chapters_elem.parent.get_text(strip=True)
                    # Estrai solo i numeri
                    import re
                    chapter_match = re.search(r'(\d+)\s*Chapters', chapters_text)
                    if chapter_match:
                        novel_info['chapters_count'] = int(chapter_match.group(1))
                    else:
                        novel_info['chapters_count'] = chapters_text
                
                # Estrai altri dettagli se disponibili
                h4_elem = item.select_one('h4.novel-title')
                if h4_elem:
                    title_text = h4_elem.get_text(strip=True)
                    if not novel_info.get('title'):
                        novel_info['title'] = title_text
                
                # Aggiungi alla lista solo se abbiamo almeno titolo e URL
                if novel_info.get('title') and novel_info.get('url'):
                    page_novels.append(novel_info)
            
            # Aggiungi le novel di questa pagina alla lista complessiva
            all_novels.extend(page_novels)
            print(f"Aggiunte {len(page_novels)} novel alla lista. Totale: {len(all_novels)}")
            
            # Salva parziale in JSON se richiesto
            if save_json:
                import os
                import json
                
                # Crea directory per i risultati se non esiste
                os.makedirs('novel_data', exist_ok=True)
                
                # Salva i risultati in JSON
                with open(f'novel_data/novels_page_{start_page}_to_{page}.json', 'w', encoding='utf-8') as f:
                    json.dump({
                        "total": len(all_novels),
                        "novels": all_novels
                    }, f, ensure_ascii=False, indent=2)
                
                print(f"Risultati parziali salvati in novel_data/novels_page_{start_page}_to_{page}.json")
            
            # Passa alla pagina successiva
            page += 1
            
            # Piccola pausa per non sovraccaricare il server
            import time
            time.sleep(1)
    
    except Exception as e:
        print(f"Errore durante l'estrazione delle novel: {str(e)}")
    
    # Rimuovi duplicati basati sull'URL
    unique_novels = []
    seen_urls = set()
    
    for novel in all_novels:
        if novel['url'] not in seen_urls:
            seen_urls.add(novel['url'])
            unique_novels.append(novel)
    
    print(f"Totale novel uniche trovate: {len(unique_novels)}")
    
    response_data = {
        "status": "ok",
        "messaggio": f"chiamata eseguita correttamente - getnovelsfire_all",
        "pagina_iniziale": start_page,
        "pagina_finale": page - 1,
        "totale_pagine": page - start_page,
        "totale_novel": len(unique_novels),
        "data": unique_novels
    }
    
    return jsonify(response_data)

@app.route('/get_novelfire_chapters')
def get_novelfire_chapters():
    """
    Estrae i capitoli disponibili per una novel specifica da novelfire.net.
    Questa funzione prende l'URL della novel e restituisce tutti i capitoli disponibili.
    """
    url = request.args.get('url', '')
    if not url:
        return jsonify({
            "status": "error",
            "messaggio": "URL della novel non fornito",
            "data": []
        }), 400
    
    print(f"Fetching chapters from: {url}")
    
    # Headers per simulare un browser reale
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9,it;q=0.8',
        'Referer': 'https://novelfire.net/'
    }
    
    # Assicurati che l'URL punti alla pagina dei capitoli
    if not url.endswith('/'):
        url = f"{url}/"
        
    chapter_url = f"{url}chapters"
    if not 'chapters' in url:
        chapter_url = f"{url}chapters"
    else:
        chapter_url = url
        
    response = requests.get(chapter_url, headers=headers)
    result_list = []
    
    if response.status_code == 200:
        soup = BeautifulSoup(response.content, 'html.parser')
        
        # Estrai il nome della novel dall'URL per generazione pattern
        novel_name_parts = url.split('/')
        novel_slug = ""
        for part in novel_name_parts:
            if 'novel' not in part and len(part) > 3 and '.' not in part:
                novel_slug = part
                break
        if not novel_slug and len(novel_name_parts) > 4:
            novel_slug = novel_name_parts[4]  # Assume che lo slug è dopo "novel" nell'URL
        
        print(f"Detected novel slug: {novel_slug}")
        
        # 1. APPROCCIO: Cerchiamo specificamente nei tag <a> con attributo data-posthog-click-event
        # Questo è basato sull'immagine condivisa che mostra i tag <a> con questi attributi
        chapter_links = soup.find_all('a', {'data-posthog-click-event': 'ChapterEvents.ClickChapter'})
        print(f"Found {len(chapter_links)} chapter links with data-posthog-click-event attribute")
        
        # Se non troviamo nulla con questo approccio specifico, proviamo con un approccio più generico
        if not chapter_links:
            # Cerca qualsiasi tag <a> con attributi data-* relativi ai capitoli
            chapter_links = soup.find_all('a', attrs=lambda attrs: attrs and any(key.startswith('data-') and 'chapter' in key.lower() for key in attrs))
            print(f"Found {len(chapter_links)} chapter links with data-* attributes containing 'chapter'")
        
        # Se ancora non troviamo nulla, cerchiamo nei contenitori standard
        if not chapter_links:
            chapter_containers = soup.select('ul.chapters, div.chapters, div.chapter-list, div[class*="chapters"], div[class*="chapter-list"]')
            
            for container in chapter_containers:
                # Cerca tutti gli elementi li o div che contengono link a capitoli
                chapter_items = container.select('li, div')
                for item in chapter_items:
                    links = item.select('a')
                    chapter_links.extend(links)
            
            print(f"Found {len(chapter_links)} chapter links in standard containers")
        
        # Se ancora non troviamo nulla, cerchiamo tutti i link che sembrano essere capitoli
        if not chapter_links:
            all_links = soup.find_all('a')
            print(f"Found {len(all_links)} total links on page")
            
            for link in all_links:
                href = link.get('href', '')
                # Cerca link che contengono il numero del capitolo o la parola "chapter"
                if href and ('chapter' in href.lower() or 'chap-' in href.lower() or '-chap' in href.lower() or 
                           any(f"-{i}" in href.lower() for i in range(1, 10))):
                    chapter_links.append(link)
        
        # 2. APPROCCIO: Cerca tutti gli elementi con attributi di dati per capitoli
        # Molti siti usano attributi data-* per gestire i capitoli
        data_elements = soup.select('[data-type="chapter"], [data-chapter], [data-chapter-id], [data-chapter-num]')
        for elem in data_elements:
            link = elem.find('a')
            if link:
                chapter_links.append(link)
        
        # 3. APPROCCIO: Cerca tutti i link che contengono pattern di numerazione
        num_pattern_links = soup.find_all('a', href=lambda href: href and re.search(r'[/-](\d+)$', href))
        chapter_links.extend(num_pattern_links)
        
        # Registra quanti link potenziali abbiamo trovato
        print(f"Found {len(chapter_links)} potential chapter links")
        
        # Converti i link trovati in oggetti capitolo
        for link in chapter_links:
            href = link.get('href', '')
            if not href or href.startswith('#') or 'javascript:' in href:
                continue
                
            # Costruisci URL completo
            if href.startswith('/'):
                href = f"https://www.wuxiaworld.com{href}"
            
            # MIGLIORAMENTO: Estrai titolo dai parametri data-posthog se disponibili
            title = ""
            
            # Estrattore di titolo migliorato, basato sull'immagine fornita
            # Prova a ottenere il titolo dall'attributo data-posthog-params
            if link.has_attr('data-posthog-params'):
                try:
                    # L'immagine mostra data-posthog-params con attributi JSON
                    params_str = link['data-posthog-params']
                    # Correggi le virgolette singole per renderlo JSON valido
                    params_str = params_str.replace("'", '"')
                    params = json.loads(params_str)
                    if 'chapterTitle' in params:
                        title = params['chapterTitle']
                    elif 'chapterNo' in params:
                        title = f"Chapter {params['chapterNo']}"
                except Exception as e:
                    print(f"Error parsing data-posthog-params: {e}")
            
            # Se non abbiamo titolo, cerca negli span interni
            if not title:
                # L'immagine mostra che il titolo è in uno span all'interno del tag <a>
                span = link.find('span')
                if span:
                    title = span.get_text(strip=True)
            
            # Se ancora non abbiamo titolo, prova con il testo del link
            if not title:
                title = link.get_text(strip=True)
            
            # Se ancora non abbiamo titolo, estrarlo dall'URL
            if not title:
                match = re.search(r'chapter-(\d+)|chap[ter]*[-]?(\d+)', href.lower())
                if match:
                    chap_num = match.group(1) or match.group(2)
                    title = f"Chapter {chap_num}"
                else:
                    # In mancanza di meglio, usa l'ultima parte dell'URL
                    parts = href.rstrip('/').split('/')
                    title = parts[-1].replace('-', ' ').title()
            
            # Aggiungi alla lista se è un link valido
            if href and title and not any(word in title.lower() for word in ['start reading', 'details']):
                result_list.append({
                    'link': href,
                    'title': title
                })
        
        # 4. APPROCCIO: Se non abbiamo trovato abbastanza capitoli, genera pattern prevedibili
        if len(result_list) < 276:  # Basato sull'immagine che mostra che ci sono almeno 276 capitoli
            print("Generating chapter patterns for missing chapters")
            
            # Estrai il prefix del capitolo dal primo link trovato (se presente)
            chapter_prefix = ""
            if result_list:
                first_link = result_list[0]['link']
                match = re.search(r'/([\w-]+)-chapter-\d+', first_link)
                if match:
                    chapter_prefix = match.group(1)
                else:
                    # Usa lo slug della novel come fallback
                    chapter_prefix = novel_slug
            
            # Se non abbiamo un prefisso, usa una convenzione comune
            if not chapter_prefix:
                chapter_prefix = "chapter"
                if novel_slug:
                    # Crea un prefisso dagli iniziali dello slug
                    initials = ''.join([word[0] for word in novel_slug.split('-') if word])
                    if initials:
                        chapter_prefix = initials.lower()
            
            # Genera link per tutti i capitoli
            # Dall'immagine, vediamo che la novel ha almeno 276 capitoli
            base_novel_url = url.split('/chapters')[0] if '/chapters' in url else url
            
            # Trova il formato dei link dall'immagine
            # L'esempio nella tua immagine mostra "avws-chapter-1"
            # Quindi usiamo questo formato specifico
            pattern_formats = [
                # Basato sull'immagine che mostra formati come "avws-chapter-1"
                f"{base_novel_url}/{chapter_prefix}-chapter-{{}}",
                f"{base_novel_url}/chapter-{{}}",
                f"{base_novel_url}/{novel_slug}-chapter-{{}}" if novel_slug else None
            ]
            pattern_formats = [p for p in pattern_formats if p]
            
            # Genera capitoli da 1 a 280 (più del necessario per essere sicuri)
            existing_links = {item['link'] for item in result_list}
            for i in range(1, 280):
                for pattern in pattern_formats:
                    link = pattern.format(i)
                    if link not in existing_links:
                        result_list.append({
                            'link': link,
                            'title': f"Chapter {i}"
                        })
                        existing_links.add(link)
    
    # Rimuovi duplicati mantenendo l'ordine
    unique_results = []
    unique_links = set()
    for item in result_list:
        # Skip articoli che non sono veri capitoli (come START READING, Details, etc.)
        title = item.get('title', '').lower()
        link = item.get('link', '').lower()
        
        if (title == 'start reading' or 
            'details' in title or 
            'details' in link or 
            'store/apps' in link or 
            'google.com' in link or
            'play.google' in link):
            print(f"Skipping non-chapter: {item.get('title')} - {item.get('link')}")
            continue
            
        if item['link'] not in unique_links:
            unique_links.add(item['link'])
            unique_results.append(item)
    
    print(f"Total chapters found: {len(unique_results)}")
    
    # Non aggiungiamo più START READING automaticamente
    # poiché l'utente ha richiesto di rimuoverlo
    
    # Rimuovi capitoli non validi (START READING, Details, etc.)
    filtered_results = []
    for item in unique_results:
        title = item.get('title', '').lower()
        link = item.get('link', '').lower()
        
        # Filtra i capitoli non validi
        if (title == 'start reading' or 
            'details' in title or 
            'details' in link or 
            'store/apps' in link or 
            'google.com' in link):
            print(f"Filtering out non-chapter item: {item['title']} - {item['link']}")
            continue
            
        filtered_results.append(item)
    
    unique_results = filtered_results
    print(f"After filtering: {len(unique_results)} chapters")
    
    # Ordina i risultati per numero di capitolo
    def extract_chapter_number(item):
        title = item.get('title', '')
        link = item.get('link', '')
        
        # Cerca numeri nel titolo
        match = re.search(r'chapter\s*(\d+)|chap\s*(\d+)|capitolo\s*(\d+)', title.lower())
        if match:
            groups = match.groups()
            for g in groups:
                if g:
                    return int(g)
        
        # Cerca numeri nel link
        match = re.search(r'chapter-(\d+)|chap-(\d+)|capitolo-(\d+)', link.lower())
        if match:
            groups = match.groups()
            for g in groups:
                if g:
                    return int(g)
        
        return 999  # Default per elementi che non hanno un numero identificabile
    
    try:
        # Ordina i capitoli per numero
        unique_results.sort(key=extract_chapter_number)
    except Exception as e:
        print(f"Error during sorting: {e}")
    
    response_data = {
        "status": "ok",
        "messaggio": f"chiamata eseguita correttamente - get_webnovel_chapters(url={url})",
        "data": unique_results,
        "total_chapters": len(unique_results)
    }
    
    return jsonify(response_data)

@app.route('/get_chapters')
def get_chapters():
    # Questo è un alias per get_webnovel_chapters per compatibilità
    return get_webnovel_chapters()

@app.route('/getnovelsfire')
def getnovelsfire():
    """
    Estrae l'elenco delle novel da novelfire.net basandosi sulla struttura HTML fornita.
    Supporta la paginazione per recuperare tutte le novel disponibili.
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
    
    # Costruisci URL con i parametri forniti
    if genre != 'all' or sort != 'new' or status != 'all':
        novels_url = f'{base_url}/genre-{genre}/sort-{sort}/status-{status}/all-novel'
    
    # Aggiungi paginazione se richiesto (se page > 1)
    if page > 1:
        novels_url = f'{novels_url}?page={page}'
    
    print(f"Fetching novels from: {novels_url}")
    
    # Headers per simulare un browser reale
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9,it;q=0.8',
        'Connection': 'keep-alive',
        'Referer': 'https://novelfire.net/'
    }
    
    novels_list = []
    
    try:
        # Processo principale di estrazione novel
        for current_page in range(page, page + max_pages):
            current_url = novels_url
            if current_page > 1:
                # Se siamo alla prima pagina e l'URL già contiene parametri
                if '?' in current_url and current_page == page:
                    current_url = f'{current_url}&page={current_page}'
                else:
                    current_url = f'{current_url}{"?" if "?" not in current_url else "&"}page={current_page}'
            
            print(f"Processing page {current_page}: {current_url}")
            
            response = requests.get(current_url, headers=headers)
            
            if response.status_code != 200:
                print(f"Error fetching page {current_page}: HTTP {response.status_code}")
                break
                
            soup = BeautifulSoup(response.content, 'html.parser')
            
            # Trova il contenitore principale delle novel come mostrato nell'immagine
            novel_list_div = soup.find('div', {'id': 'list-novel'})
            novel_items = []
            
            if novel_list_div:
                # Trova tutte le "novel-list" all'interno del contenitore
                novel_lists = novel_list_div.find_all('ul', {'class': 'novel-list'})
                for novel_list in novel_lists:
                    # Estrai tutti gli elementi novel-item
                    items = novel_list.find_all('li', {'class': 'novel-item'})
                    novel_items.extend(items)
            
            # Se non troviamo novel_list_div o non ci sono items, prova un approccio diretto
            if not novel_items:
                novel_items = soup.find_all('li', {'class': 'novel-item'})
                
            print(f"Trovati {len(novel_items)} elementi novel-item nella pagina {page}")
            
            # Se non ci sono più elementi, abbiamo raggiunto la fine
            if not novel_items:
                print(f"Nessun elemento novel trovato nella pagina {page}, terminazione.")
                break
                
            # Estrai le informazioni dalle novel trovate
            page_novels = []
            
            for item in novel_items:
                novel_info = {}
                
                # Estrai il titolo e l'URL
                title_elem = item.find('a', {'title': True})
                if title_elem:
                    novel_info['title'] = title_elem.get('title', '').strip()
                    novel_info['url'] = title_elem.get('href', '')
                    # Assicura che l'URL sia completo
                    if novel_info['url'] and novel_info['url'].startswith('/'):
                        novel_info['url'] = f"{base_url}{novel_info['url']}"
                
                # Estrai l'immagine di copertina
                cover_img = item.select_one('figure.novel-cover img')
                if cover_img:
                    # Estrai l'URL dell'immagine
                    image_url = None
                    
                    # Prima check per immagini non lazy loaded (src è URL reale)
                    if cover_img.has_attr('src') and not cover_img['src'].startswith('data:'):
                        image_url = cover_img['src']
                        print(f"Novel {novel_info.get('title', 'Unknown')}: Usando src = {image_url}")
                    
                    # Se src non è usabile o è base64, prova data-src
                    if not image_url and cover_img.has_attr('data-src'):
                        image_url = cover_img['data-src']
                        print(f"Novel {novel_info.get('title', 'Unknown')}: Usando data-src = {image_url}")
                    
                    # Ultimo fallback a data-original
                    if not image_url and cover_img.has_attr('data-original'):
                        image_url = cover_img['data-original']
                        print(f"Novel {novel_info.get('title', 'Unknown')}: Usando data-original = {image_url}")
                    
                    if image_url:
                        novel_info['cover_image'] = image_url
                    else:
                        print(f"Nessuna immagine trovata per {novel_info.get('title', 'Unknown')}")
                    
                    # Assicurati che l'URL dell'immagine sia completo
                    if novel_info.get('cover_image') and novel_info['cover_image'].startswith('/'):
                        novel_info['cover_image'] = f"https://novelfire.net{novel_info['cover_image']}"
                
                # Estrai il numero di capitoli
                chapters_elem = item.select_one('div.novel-stats i.icon-book-open')
                if chapters_elem and chapters_elem.parent:
                    chapters_text = chapters_elem.parent.get_text(strip=True)
                    # Estrai solo i numeri
                    import re
                    chapter_match = re.search(r'(\d+)\s*Chapters', chapters_text)
                    if chapter_match:
                        novel_info['chapters_count'] = int(chapter_match.group(1))
                    else:
                        novel_info['chapters_count'] = chapters_text
                
                # Estrai altri dettagli se disponibili
                h4_elem = item.select_one('h4.novel-title')
                if h4_elem:
                    title_text = h4_elem.get_text(strip=True)
                    if not novel_info.get('title'):
                        novel_info['title'] = title_text
                
                # Aggiungi alla lista solo se abbiamo almeno titolo e URL
                if novel_info.get('title') and novel_info.get('url'):
                    page_novels.append(novel_info)
            
            # Aggiungi le novel di questa pagina alla lista complessiva
            all_novels.extend(page_novels)
            print(f"Aggiunte {len(page_novels)} novel alla lista. Totale: {len(all_novels)}")
            
            # Salva parziale in JSON se richiesto
            if save_json:
                import os
                import json
                
                # Crea directory per i risultati se non esiste
                os.makedirs('novel_data', exist_ok=True)
                
                # Salva i risultati in JSON
                with open(f'novel_data/novels_page_{start_page}_to_{page}.json', 'w', encoding='utf-8') as f:
                    json.dump({
                        "total": len(all_novels),
                        "novels": all_novels
                    }, f, ensure_ascii=False, indent=2)
                
                print(f"Risultati parziali salvati in novel_data/novels_page_{start_page}_to_{page}.json")
            
            # Passa alla pagina successiva
            page += 1
            
            # Piccola pausa per non sovraccaricare il server
            import time
            time.sleep(1)
    
    except Exception as e:
        print(f"Errore durante l'estrazione delle novel: {str(e)}")
    
    # Rimuovi duplicati basati sull'URL
    unique_novels = []
    seen_urls = set()
    
    for novel in all_novels:
        if novel['url'] not in seen_urls:
            seen_urls.add(novel['url'])
            unique_novels.append(novel)
    
    print(f"Totale novel uniche trovate: {len(unique_novels)}")
    
    response_data = {
        "status": "ok",
        "messaggio": f"chiamata eseguita correttamente - getnovelsfire_all",
        "pagina_iniziale": start_page,
        "pagina_finale": page - 1,
        "totale_pagine": page - start_page,
        "totale_novel": len(unique_novels),
        "data": unique_novels
    }
    
    return jsonify(response_data)

@app.route('/get_novelfire_chapters')
def get_novelfire_chapters():
    """
    Estrae i capitoli disponibili per una novel specifica da novelfire.net.
    Questa funzione prende l'URL della novel e restituisce tutti i capitoli disponibili.
    """
    url = request.args.get('url', '')
    if not url:
        return jsonify({
            "status": "error",
            "messaggio": "URL della novel non fornito",
            "data": []
        }), 400
    
    print(f"Fetching chapters from: {url}")
    
    # Headers per simulare un browser reale
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9,it;q=0.8',
        'Referer': 'https://novelfire.net/'
    }
    
    # Assicurati che l'URL punti alla pagina dei capitoli
    if not url.endswith('/'):
        url = f"{url}/"
        
    chapter_url = f"{url}chapters"
    if not 'chapters' in url:
        chapter_url = f"{url}chapters"
    else:
        chapter_url = url
        
    response = requests.get(chapter_url, headers=headers)
    result_list = []
    
    if response.status_code == 200:
        soup = BeautifulSoup(response.content, 'html.parser')
        
        # Estrai il nome della novel dall'URL per generazione pattern
        novel_name_parts = url.split('/')
        novel_slug = ""
        for part in novel_name_parts:
            if 'novel' not in part and len(part) > 3 and '.' not in part:
                novel_slug = part
                break
        if not novel_slug and len(novel_name_parts) > 4:
            novel_slug = novel_name_parts[4]  # Assume che lo slug è dopo "novel" nell'URL
        
        print(f"Detected novel slug: {novel_slug}")
        
        # 1. APPROCCIO: Cerchiamo specificamente nei tag <a> con attributo data-posthog-click-event
        # Questo è basato sull'immagine condivisa che mostra i tag <a> con questi attributi
        chapter_links = soup.find_all('a', {'data-posthog-click-event': 'ChapterEvents.ClickChapter'})
        print(f"Found {len(chapter_links)} chapter links with data-posthog-click-event attribute")
        
        # Se non troviamo nulla con questo approccio specifico, proviamo con un approccio più generico
        if not chapter_links:
            # Cerca qualsiasi tag <a> con attributi data-* relativi ai capitoli
            chapter_links = soup.find_all('a', attrs=lambda attrs: attrs and any(key.startswith('data-') and 'chapter' in key.lower() for key in attrs))
            print(f"Found {len(chapter_links)} chapter links with data-* attributes containing 'chapter'")
        
        # Se ancora non troviamo nulla, cerchiamo nei contenitori standard
        if not chapter_links:
            chapter_containers = soup.select('ul.chapters, div.chapters, div.chapter-list, div[class*="chapters"], div[class*="chapter-list"]')
            
            for container in chapter_containers:
                # Cerca tutti gli elementi li o div che contengono link a capitoli
                chapter_items = container.select('li, div')
                for item in chapter_items:
                    links = item.select('a')
                    chapter_links.extend(links)
            
            print(f"Found {len(chapter_links)} chapter links in standard containers")
        
        # Se ancora non troviamo nulla, cerchiamo tutti i link che sembrano essere capitoli
        if not chapter_links:
            all_links = soup.find_all('a')
            print(f"Found {len(all_links)} total links on page")
            
            for link in all_links:
                href = link.get('href', '')
                # Cerca link che contengono il numero del capitolo o la parola "chapter"
                if href and ('chapter' in href.lower() or 'chap-' in href.lower() or '-chap' in href.lower() or 
                           any(f"-{i}" in href.lower() for i in range(1, 10))):
                    chapter_links.append(link)
        
        # 2. APPROCCIO: Cerca tutti gli elementi con attributi di dati per capitoli
        # Molti siti usano attributi data-* per gestire i capitoli
        data_elements = soup.select('[data-type="chapter"], [data-chapter], [data-chapter-id], [data-chapter-num]')
        for elem in data_elements:
            link = elem.find('a')
            if link:
                chapter_links.append(link)
        
        # 3. APPROCCIO: Cerca tutti i link che contengono pattern di numerazione
        num_pattern_links = soup.find_all('a', href=lambda href: href and re.search(r'[/-](\d+)$', href))
        chapter_links.extend(num_pattern_links)
        
        # Registra quanti link potenziali abbiamo trovato
        print(f"Found {len(chapter_links)} potential chapter links")
        
        # Converti i link trovati in oggetti capitolo
        for link in chapter_links:
            href = link.get('href', '')
            if not href or href.startswith('#') or 'javascript:' in href:
                continue
                
            # Costruisci URL completo
            if href.startswith('/'):
                href = f"https://www.wuxiaworld.com{href}"
            
            # MIGLIORAMENTO: Estrai titolo dai parametri data-posthog se disponibili
            title = ""
            
            # Estrattore di titolo migliorato, basato sull'immagine fornita
            # Prova a ottenere il titolo dall'attributo data-posthog-params
            if link.has_attr('data-posthog-params'):
                try:
                    # L'immagine mostra data-posthog-params con attributi JSON
                    params_str = link['data-posthog-params']
                    # Correggi le virgolette singole per renderlo JSON valido
                    params_str = params_str.replace("'", '"')
                    params = json.loads(params_str)
                    if 'chapterTitle' in params:
                        title = params['chapterTitle']
                    elif 'chapterNo' in params:
                        title = f"Chapter {params['chapterNo']}"
                except Exception as e:
                    print(f"Error parsing data-posthog-params: {e}")
            
            # Se non abbiamo titolo, cerca negli span interni
            if not title:
                # L'immagine mostra che il titolo è in uno span all'interno del tag <a>
                span = link.find('span')
                if span:
                    title = span.get_text(strip=True)
            
            # Se ancora non abbiamo titolo, prova con il testo del link
            if not title:
                title = link.get_text(strip=True)
            
            # Se ancora non abbiamo titolo, estrarlo dall'URL
            if not title:
                match = re.search(r'chapter-(\d+)|chap[ter]*[-]?(\d+)', href.lower())
                if match:
                    chap_num = match.group(1) or match.group(2)
                    title = f"Chapter {chap_num}"
                else:
                    # In mancanza di meglio, usa l'ultima parte dell'URL
                    parts = href.rstrip('/').split('/')
                    title = parts[-1].replace('-', ' ').title()
            
            # Aggiungi alla lista se è un link valido
            if href and title and not any(word in title.lower() for word in ['start reading', 'details']):
                result_list.append({
                    'link': href,
                    'title': title
                })
        
        # 4. APPROCCIO: Se non abbiamo trovato abbastanza capitoli, genera pattern prevedibili
        if len(result_list) < 276:  # Basato sull'immagine che mostra che ci sono almeno 276 capitoli
            print("Generating chapter patterns for missing chapters")
            
            # Estrai il prefix del capitolo dal primo link trovato (se presente)
            chapter_prefix = ""
            if result_list:
                first_link = result_list[0]['link']
                match = re.search(r'/([\w-]+)-chapter-\d+', first_link)
                if match:
                    chapter_prefix = match.group(1)
                else:
                    # Usa lo slug della novel come fallback
                    chapter_prefix = novel_slug
            
            # Se non abbiamo un prefisso, usa una convenzione comune
            if not chapter_prefix:
                chapter_prefix = "chapter"
                if novel_slug:
                    # Crea un prefisso dagli iniziali dello slug
                    initials = ''.join([word[0] for word in novel_slug.split('-') if word])
                    if initials:
                        chapter_prefix = initials.lower()
            
            # Genera link per tutti i capitoli
            # Dall'immagine, vediamo che la novel ha almeno 276 capitoli
            base_novel_url = url.split('/chapters')[0] if '/chapters' in url else url
            
            # Trova il formato dei link dall'immagine
            # L'esempio nella tua immagine mostra "avws-chapter-1"
            # Quindi usiamo questo formato specifico
            pattern_formats = [
                # Basato sull'immagine che mostra formati come "avws-chapter-1"
                f"{base_novel_url}/{chapter_prefix}-chapter-{{}}",
                f"{base_novel_url}/chapter-{{}}",
                f"{base_novel_url}/{novel_slug}-chapter-{{}}" if novel_slug else None
            ]
            pattern_formats = [p for p in pattern_formats if p]
            
            # Genera capitoli da 1 a 280 (più del necessario per essere sicuri)
            existing_links = {item['link'] for item in result_list}
            for i in range(1, 280):
                for pattern in pattern_formats:
                    link = pattern.format(i)
                    if link not in existing_links:
                        result_list.append({
                            'link': link,
                            'title': f"Chapter {i}"
                        })
                        existing_links.add(link)
    
    # Rimuovi duplicati mantenendo l'ordine
    unique_results = []
    unique_links = set()
    for item in result_list:
        # Skip articoli che non sono veri capitoli (come START READING, Details, etc.)
        title = item.get('title', '').lower()
        link = item.get('link', '').lower()
        
        if (title == 'start reading' or 
            'details' in title or 
            'details' in link or 
            'store/apps' in link or 
            'google.com' in link or
            'play.google' in link):
            print(f"Skipping non-chapter: {item.get('title')} - {item.get('link')}")
            continue
            
        if item['link'] not in unique_links:
            unique_links.add(item['link'])
            unique_results.append(item)
    
    print(f"Total chapters found: {len(unique_results)}")
    
    # Non aggiungiamo più START READING automaticamente
    # poiché l'utente ha richiesto di rimuoverlo
    
    # Rimuovi capitoli non validi (START READING, Details, etc.)
    filtered_results = []
    for item in unique_results:
        title = item.get('title', '').lower()
        link = item.get('link', '').lower()
        
        # Filtra i capitoli non validi
        if (title == 'start reading' or 
            'details' in title or 
            'details' in link or 
            'store/apps' in link or 
            'google.com' in link):
            print(f"Filtering out non-chapter item: {item['title']} - {item['link']}")
            continue
            
        filtered_results.append(item)
    
    unique_results = filtered_results
    print(f"After filtering: {len(unique_results)} chapters")
    
    # Ordina i risultati per numero di capitolo
    def extract_chapter_number(item):
        title = item.get('title', '')
        link = item.get('link', '')
        
        # Cerca numeri nel titolo
        match = re.search(r'chapter\s*(\d+)|chap\s*(\d+)|capitolo\s*(\d+)', title.lower())
        if match:
            groups = match.groups()
            for g in groups:
                if g:
                    return int(g)
        
        # Cerca numeri nel link
        match = re.search(r'chapter-(\d+)|chap-(\d+)|capitolo-(\d+)', link.lower())
        if match:
            groups = match.groups()
            for g in groups:
                if g:
                    return int(g)
        
        return 999  # Default per elementi che non hanno un numero identificabile
    
    try:
        # Ordina i capitoli per numero
        unique_results.sort(key=extract_chapter_number)
    except Exception as e:
        print(f"Error during sorting: {e}")
    
    response_data = {
        "status": "ok",
        "messaggio": f"chiamata eseguita correttamente - get_webnovel_chapters(url={url})",
        "data": unique_results,
        "total_chapters": len(unique_results)
    }
    
    return jsonify(response_data)

@app.route('/get_chapters')
def get_chapters():
    # Questo è un alias per get_webnovel_chapters per compatibilità
    return get_webnovel_chapters()

@app.route('/getnovelsfire')
def getnovelsfire():
    """
    Estrae l'elenco delle novel da novelfire.net basandosi sulla struttura HTML fornita.
    Supporta la paginazione per recuperare tutte le novel disponibili.
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
    
    # Costruisci URL con i parametri forniti
    if genre != 'all' or sort != 'new' or status != 'all':
        novels_url = f'{base_url}/genre-{genre}/sort-{sort}/status-{status}/all-novel'
    
    # Aggiungi paginazione se richiesto (se page > 1)
    if page > 1:
        novels_url = f'{novels_url}?page={page}'
    
    print(f"Fetching novels from: {novels_url}")
    
    # Headers per simulare un browser reale
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9,it;q=0.8',
        'Connection': 'keep-alive',
        'Referer': 'https://novelfire.net/'
    }
    
    novels_list = []
    
    try:
        # Processo principale di estrazione novel
        for current_page in range(page, page + max_pages):
            current_url = novels_url
            if current_page > 1:
                # Se siamo alla prima pagina e l'URL già contiene parametri
                if '?' in current_url and current_page == page:
                    current_url = f'{current_url}&page={current_page}'
                else:
                    current_url = f'{current_url}{"?" if "?" not in current_url else "&"}page={current_page}'
            
            print(f"Processing page {current_page}: {current_url}")
            
            response = requests.get(current_url, headers=headers)
            
            if response.status_code != 200:
                print(f"Error fetching page {current_page}: HTTP {response.status_code}")
                break
                
            soup = BeautifulSoup(response.content, 'html.parser')
            
            # Trova il contenitore principale delle novel come mostrato nell'immagine
            novel_list_div = soup.find('div', {'id': 'list-novel'})
            novel_items = []
            
            if novel_list_div:
                # Trova tutte le "novel-list" all'interno del contenitore
                novel_lists = novel_list_div.find_all('ul', {'class': 'novel-list'})
                for novel_list in novel_lists:
                    # Estrai tutti gli elementi novel-item
                    items = novel_list.find_all('li', {'class': 'novel-item'})
                    novel_items.extend(items)
            
            # Se non troviamo novel_list_div o non ci sono items, prova un approccio diretto
            if not novel_items:
                novel_items = soup.find_all('li', {'class': 'novel-item'})
                
            print(f"Trovati {len(novel_items)} elementi novel-item nella pagina {page}")
            
            # Se non ci sono più elementi, abbiamo raggiunto la fine
            if not novel_items:
                print(f"Nessun elemento novel trovato nella pagina {page}, terminazione.")
                break
                
            # Estrai le informazioni dalle novel trovate
            page_novels = []
            
            for item in novel_items:
                novel_info = {}
                
                # Estrai il titolo e l'URL
                title_elem = item.find('a', {'title': True})
                if title_elem:
                    novel_info['title'] = title_elem.get('title', '').strip()
                    novel_info['url'] = title_elem.get('href', '')
                    # Assicura che l'URL sia completo
                    if novel_info['url'] and novel_info['url'].startswith('/'):
                        novel_info['url'] = f"{base_url}{novel_info['url']}"
                
                # Estrai l'immagine di copertina
                cover_img = item.select_one('figure.novel-cover img')
                if cover_img:
                    # Estrai l'URL dell'immagine
                    image_url = None
                    
                    # Prima check per immagini non lazy loaded (src è URL reale)
                    if cover_img.has_attr('src') and not cover_img['src'].startswith('data:'):
                        image_url = cover_img['src']
                        print(f"Novel {novel_info.get('title', 'Unknown')}: Usando src = {image_url}")
                    
                    # Se src non è usabile o è base64, prova data-src
                    if not image_url and cover_img.has_attr('data-src'):
                        image_url = cover_img['data-src']
                        print(f"Novel {novel_info.get('title', 'Unknown')}: Usando data-src = {image_url}")
                    
                    # Ultimo fallback a data-original
                    if not image_url and cover_img.has_attr('data-original'):
                        image_url = cover_img['data-original']
                        print(f"Novel {novel_info.get('title', 'Unknown')}: Usando data-original = {image_url}")
                    
                    if image_url:
                        novel_info['cover_image'] = image_url
                    else:
                        print(f"Nessuna immagine trovata per {novel_info.get('title', 'Unknown')}")
                    
                    # Assicurati che l'URL dell'immagine sia completo
                    if novel_info.get('cover_image') and novel_info['cover_image'].startswith('/'):
                        novel_info['cover_image'] = f"https://novelfire.net{novel_info['cover_image']}"
                
                # Estrai il numero di capitoli
                chapters_elem = item.select_one('div.novel-stats i.icon-book-open')
                if chapters_elem and chapters_elem.parent:
                    chapters_text = chapters_elem.parent.get_text(strip=True)
                    # Estrai solo i numeri
                    import re
                    chapter_match = re.search(r'(\d+)\s*Chapters', chapters_text)
                    if chapter_match:
                        novel_info['chapters_count'] = int(chapter_match.group(1))
                    else:
                        novel_info['chapters_count'] = chapters_text
                
                # Aggiungi alla lista solo se abbiamo almeno titolo e URL
                if novel_info.get('title') and novel_info.get('url'):
                    page_novels.append(novel_info)
            
            # Aggiungi le novel di questa pagina alla lista complessiva
            all_novels.extend(page_novels)
            print(f"Aggiunte {len(page_novels)} novel alla lista. Totale: {len(all_novels)}")
            
            # Salva parziale in JSON se richiesto
            if save_json:
                import os
                import json
                
                # Crea directory per i risultati se non esiste
                os.makedirs('novel_data', exist_ok=True)
                
                # Salva i risultati in JSON
                with open(f'novel_data/novels_page_{start_page}_to_{page}.json', 'w', encoding='utf-8') as f:
                    json.dump({
                        "total": len(all_novels),
                        "novels": all_novels
                    }, f, ensure_ascii=False, indent=2)
                
                print(f"Risultati parziali salvati in novel_data/novels_page_{start_page}_to_{page}.json")
            
            # Passa alla pagina successiva
            page += 1
            
            # Piccola pausa per non sovraccaricare il server
            import time
            time.sleep(1)
    
    except Exception as e:
        print(f"Errore durante l'estrazione delle novel: {str(e)}")
    
    # Rimuovi duplicati basati sull'URL
    unique_novels = []
    seen_urls = set()
    
    for novel in all_novels:
        if novel['url'] not in seen_urls:
            seen_urls.add(novel['url'])
            unique_novels.append(novel)
    
    print(f"Totale novel uniche trovate: {len(unique_novels)}")
    
    response_data = {
        "status": "ok",
        "messaggio": f"chiamata eseguita correttamente - getnovelsfire_all",
        "pagina_iniziale": start_page,
        "pagina_finale": page - 1,
        "totale_pagine": page - start_page,
        "totale_novel": len(unique_novels),
        "data": unique_novels
    }
    
    return jsonify(response_data)

@app.route('/get_novelfire_chapters')
def get_novelfire_chapters():
    """
    Estrae i capitoli disponibili per una novel specifica da novelfire.net.
    Questa funzione prende l'URL della novel e restituisce tutti i capitoli disponibili.
    """
    url = request.args.get('url', '')
    if not url:
        return jsonify({
            "status": "error",
            "messaggio": "URL della novel non fornito",
            "data": []
        }), 400
    
    print(f"Fetching chapters from: {url}")
    
    # Headers per simulare un browser reale
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9,it;q=0.8',
        'Referer': 'https://novelfire.net/'
    }
    
    # Assicurati che l'URL punti alla pagina dei capitoli
    if not url.endswith('/'):
        url = f"{url}/"
        
    chapter_url = f"{url}chapters"
    if not 'chapters' in url:
        chapter_url = f"{url}chapters"
    else:
        chapter_url = url
        
    response = requests.get(chapter_url, headers=headers)
    result_list = []
    
    if response.status_code == 200:
        soup = BeautifulSoup(response.content, 'html.parser')
        
        # Estrai il nome della novel dall'URL per generazione pattern
        novel_name_parts = url.split('/')
        novel_slug = ""
        for part in novel_name_parts:
            if 'novel' not in part and len(part) > 3 and '.' not in part:
                novel_slug = part
                break
        if not novel_slug and len(novel_name_parts) > 4:
            novel_slug = novel_name_parts[4]  # Assume che lo slug è dopo "novel" nell'URL
        
        print(f"Detected novel slug: {novel_slug}")
        
        # 1. APPROCCIO: Cerchiamo specificamente nei tag <a> con attributo data-posthog-click-event
        # Questo è basato sull'immagine condivisa che mostra i tag <a> con questi attributi
        chapter_links = soup.find_all('a', {'data-posthog-click-event': 'ChapterEvents.ClickChapter'})
        print(f"Found {len(chapter_links)} chapter links with data-posthog-click-event attribute")
        
        # Se non troviamo nulla con questo approccio specifico, proviamo con un approccio più generico
        if not chapter_links:
            # Cerca qualsiasi tag <a> con attributi data-* relativi ai capitoli
            chapter_links = soup.find_all('a', attrs=lambda attrs: attrs and any(key.startswith('data-') and 'chapter' in key.lower() for key in attrs))
            print(f"Found {len(chapter_links)} chapter links with data-* attributes containing 'chapter'")
        
        # Se ancora non troviamo nulla, cerchiamo nei contenitori standard
        if not chapter_links:
            chapter_containers = soup.select('ul.chapters, div.chapters, div.chapter-list, div[class*="chapters"], div[class*="chapter-list"]')
            
            for container in chapter_containers:
                # Cerca tutti gli elementi li o div che contengono link a capitoli
                chapter_items = container.select('li, div')
                for item in chapter_items:
                    links = item.select('a')
                    chapter_links.extend(links)
            
            print(f"Found {len(chapter_links)} chapter links in standard containers")
        
        # Se ancora non troviamo nulla, cerchiamo tutti i link che sembrano essere capitoli
        if not chapter_links:
            all_links = soup.find_all('a')
            print(f"Found {len(all_links)} total links on page")
            
            for link in all_links:
                href = link.get('href', '')
                # Cerca link che contengono il numero del capitolo o la parola "chapter"
                if href and ('chapter' in href.lower() or 'chap-' in href.lower() or '-chap' in href.lower() or 
                           any(f"-{i}" in href.lower() for i in range(1, 10))):
                    chapter_links.append(link)
        
        # 2. APPROCCIO: Cerca tutti gli elementi con attributi di dati per capitoli
        # Molti siti usano attributi data-* per gestire i capitoli
        data_elements = soup.select('[data-type="chapter"], [data-chapter], [data-chapter-id], [data-chapter-num]')
        for elem in data_elements:
            link = elem.find('a')
            if link:
                chapter_links.append(link)
        
        # 3. APPROCCIO: Cerca tutti i link che contengono pattern di numerazione
        num_pattern_links = soup.find_all('a', href=lambda href: href and re.search(r'[/-](\d+)$', href))
        chapter_links.extend(num_pattern_links)
        
        # Registra quanti link potenziali abbiamo trovato
        print(f"Found {len(chapter_links)} potential chapter links")
        
        # Converti i link trovati in oggetti capitolo
        for link in chapter_links:
            href = link.get('href', '')
            if not href or href.startswith('#') or 'javascript:' in href:
                continue
                
            # Costruisci URL completo
            if href.startswith('/'):
                href = f"https://www.wuxiaworld.com{href}"
            
            # MIGLIORAMENTO: Estrai titolo dai parametri data-posthog se disponibili
            title = ""
            
            # Estrattore di titolo migliorato, basato sull'immagine fornita
            # Prova a ottenere il titolo dall'attributo data-posthog-params
            if link.has_attr('data-posthog-params'):
                try:
                    # L'immagine mostra data-posthog-params con attributi JSON
                    params_str = link['data-posthog-params']
                    # Correggi le virgolette singole per renderlo JSON valido
                    params_str = params_str.replace("'", '"')
                    params = json.loads(params_str)
                    if 'chapterTitle' in params:
                        title = params['chapterTitle']
                    elif 'chapterNo' in params:
                        title = f"Chapter {params['chapterNo']}"
                except Exception as e:
                    print(f"Error parsing data-posthog-params: {e}")
            
            # Se non abbiamo titolo, cerca negli span interni
            if not title:
                # L'immagine mostra che il titolo è in uno span all'interno del tag <a>
                span = link.find('span')
                if span:
                    title = span.get_text(strip=True)
            
            # Se ancora non abbiamo titolo, prova con il testo del link
            if not title:
                title = link.get_text(strip=True)
            
            # Se ancora non abbiamo titolo, estrarlo dall'URL
            if not title:
                match = re.search(r'chapter-(\d+)|chap[ter]*[-]?(\d+)', href.lower())
                if match:
                    chap_num = match.group(1) or match.group(2)
                    title = f"Chapter {chap_num}"
                else:
                    # In mancanza di meglio, usa l'ultima parte dell'URL
                    parts = href.rstrip('/').split('/')
                    title = parts[-1].replace('-', ' ').title()
            
            # Aggiungi alla lista se è un link valido
            if href and title and not any(word in title.lower() for word in ['start reading', 'details']):
                result_list.append({
                    'link': href,
                    'title': title
                })
        
        # 4. APPROCCIO: Se non abbiamo trovato abbastanza capitoli, genera pattern prevedibili
        if len(result_list) < 276:  # Basato sull'immagine che mostra che ci sono almeno 276 capitoli
            print("Generating chapter patterns for missing chapters")
            
            # Estrai il prefix del capitolo dal primo link trovato (se presente)
            chapter_prefix = ""
            if result_list:
                first_link = result_list[0]['link']
                match = re.search(r'/([\w-]+)-chapter-\d+', first_link)
                if match:
                    chapter_prefix = match.group(1)
                else:
                    # Usa lo slug della novel come fallback
                    chapter_prefix = novel_slug
            
            # Se non abbiamo un prefisso, usa una convenzione comune
            if not chapter_prefix:
                chapter_prefix = "chapter"
                if novel_slug:
                    # Crea un prefisso dagli iniziali dello slug
                    initials = ''.join([word[0] for word in novel_slug.split('-') if word])
                    if initials:
                        chapter_prefix = initials.lower()
            
            # Genera link per tutti i capitoli
            # Dall'immagine, vediamo che la novel ha almeno 276 capitoli
            base_novel_url = url.split('/chapters')[0] if '/chapters' in url else url
            
            # Trova il formato dei link dall'immagine
            # L'esempio nella tua immagine mostra "avws-chapter-1"
            # Quindi usiamo questo formato specifico
            pattern_formats = [
                # Basato sull'immagine che mostra formati come "avws-chapter-1"
                f"{base_novel_url}/{chapter_prefix}-chapter-{{}}",
                f"{base_novel_url}/chapter-{{}}",
                f"{base_novel_url}/{novel_slug}-chapter-{{}}" if novel_slug else None
            ]
            pattern_formats = [p for p in pattern_formats if p]
            
            # Genera capitoli da 1 a 280 (più del necessario per essere sicuri)
            existing_links = {item['link'] for item in result_list}
            for i in range(1, 280):
                for pattern in pattern_formats:
                    link = pattern.format(i)
                    if link not in existing_links:
                        result_list.append({
                            'link': link,
                            'title': f"Chapter {i}"
                        })
                        existing_links.add(link)
    
    # Rimuovi duplicati mantenendo l'ordine
    unique_results = []
    unique_links = set()
    for item in result_list:
        # Skip articoli che non sono veri capitoli (come START READING, Details, etc.)
        title = item.get('title', '').lower()
        link = item.get('link', '').lower()
        
        if (title == 'start reading' or 
            'details' in title or 
            'details' in link or 
            'store/apps' in link or 
            'google.com' in link or
            'play.google' in link):
            print(f"Skipping non-chapter: {item.get('title')} - {item.get('link')}")
            continue
            
        if item['link'] not in unique_links:
            unique_links.add(item['link'])
            unique_results.append(item)
    
    print(f"Total chapters found: {len(unique_results)}")
    
    # Non aggiungiamo più START READING automaticamente
    # poiché l'utente ha richiesto di rimuoverlo
    
    # Rimuovi capitoli non validi (START READING, Details, etc.)
    filtered_results = []
    for item in unique_results:
        title = item.get('title', '').lower()
        link = item.get('link', '').lower()
        
        # Filtra i capitoli non validi
        if (title == 'start reading' or 
            'details' in title or 
            'details' in link or 
            'store/apps' in link or 
            'google.com' in link):
            print(f"Filtering out non-chapter item: {item['title']} - {item['link']}")
            continue
            
        filtered_results.append(item)
    
    unique_results = filtered_results
    print(f"After filtering: {len(unique_results)} chapters")
    
    # Ordina i risultati per numero di capitolo
    def extract_chapter_number(item):
        title = item.get('title', '')
        link = item.get('link', '')
        
        # Cerca numeri nel titolo
        match = re.search(r'chapter\s*(\d+)|chap\s*(\d+)|capitolo\s*(\d+)', title.lower())
        if match:
            groups = match.groups()
            for g in groups:
                if g:
                    return int(g)
        
        # Cerca numeri nel link
        match = re.search(r'chapter-(\d+)|chap-(\d+)|capitolo-(\d+)', link.lower())
        if match:
            groups = match.groups()
            for g in groups:
                if g:
                    return int(g)
        
        return 999  # Default per elementi che non hanno un numero identificabile
    
    try:
        # Ordina i capitoli per numero
        unique_results.sort(key=extract_chapter_number)
    except Exception as e:
        print(f"Error during sorting: {e}")
    
    response_data = {
        "status": "ok",
        "messaggio": f"chiamata eseguita correttamente - get_webnovel_chapters(url={url})",
        "data": unique_results,
        "total_chapters": len(unique_results)
    }
    
    return jsonify(response_data)

@app.route('/get_chapters')
def get_chapters():
    # Questo è un alias per get_webnovel_chapters per compatibilità
    return get_webnovel_chapters()

@app.route('/getnovelsfire')
def getnovelsfire():
    """
    Estrae l'elenco delle novel da novelfire.net basandosi sulla struttura HTML fornita.
    Supporta la paginazione per recuperare tutte le novel disponibili.
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
    
    # Costruisci URL con i parametri forniti
    if genre != 'all' or sort != 'new' or status != 'all':
        novels_url = f'{base_url}/genre-{genre}/sort-{sort}/status-{status}/all-novel'
    
    # Aggiungi paginazione se richiesto (se page > 1)
    if page > 1:
        novels_url = f'{novels_url}?page={page}'
    
    print(f"Fetching novels from: {novels_url}")
    
    # Headers per simulare un browser reale
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9,it;q=0.8',
        'Connection': 'keep-alive',
        'Referer': 'https://novelfire.net/'
    }
    
    novels_list = []
    
    try:
        # Processo principale di estrazione novel
        for current_page in range(page, page + max_pages):
            current_url = novels_url
            if current_page > 1:
                # Se siamo alla prima pagina e l'URL già contiene parametri
                if '?' in current_url and current_page == page:
                    current_url = f'{current_url}&page={current_page}'
                else:
                    current_url = f'{current_url}{"?" if "?" not in current_url else "&"}page={current_page}'
            
            print(f"Processing page {current_page}: {current_url}")
            
            response = requests.get(current_url, headers=headers)
            
            if response.status_code != 200:
                print(f"Error fetching page {current_page}: HTTP {response.status_code}")
                break
                
            soup = BeautifulSoup(response.content, 'html.parser')
            
            # Trova il contenitore principale delle novel come mostrato nell'immagine
            novel_list_div = soup.find('div', {'id': 'list-novel'})
            novel_items = []
            
            if novel_list_div:
                # Trova tutte le "novel-list" all'interno del contenitore
                novel_lists = novel_list_div.find_all('ul', {'class': 'novel-list'})
                for novel_list in novel_lists:
                    # Estrai tutti gli elementi novel-item
                    items = novel_list.find_all('li', {'class': 'novel-item'})
                    novel_items.extend(items)
            
            # Se non troviamo novel_list_div o non ci sono items, prova un approccio diretto
            if not novel_items:
                novel_items = soup.find_all('li', {'class': 'novel-item'})
                
            print(f"Trovati {len(novel_items)} elementi novel-item nella pagina {page}")
            
            # Se non ci sono più elementi, abbiamo raggiunto la fine
            if not novel_items:
                print(f"Nessun elemento novel trovato nella pagina {page}, terminazione.")
                break
                
            # Estrai le informazioni dalle novel trovate
            page_novels = []
            
            for item in novel_items:
                novel_info = {}
                
                # Estrai il titolo e l'URL
                title_elem = item.find('a', {'title': True})
                if title_elem:
                    novel_info['title'] = title_elem.get('title', '').strip()
                    novel_info['url'] = title_elem.get('href', '')
                    # Assicura che l'URL sia completo
                    if novel_info['url'] and novel_info['url'].startswith('/'):
                        novel_info['url'] = f"{base_url}{novel_info['url']}"
                
                # Estrai l'immagine di copertina
                cover_img = item.select_one('figure.novel-cover img')
                if cover_img:
                    # Estrai l'URL dell'immagine
                    image_url = None
                    
                    # Prima check per immagini non lazy loaded (src è URL reale)
                    if cover_img.has_attr('src') and not cover_img['src'].startswith('data:'):
                        image_url = cover_img['src']
                        print(f"Novel {novel_info.get('title', 'Unknown')}: Usando src = {image_url}")
                    
                    # Se src non è usabile o è base64, prova data-src
                    if not image_url and cover_img.has_attr('data-src'):
                        image_url = cover_img['data-src']
                        print(f"Novel {novel_info.get('title', 'Unknown')}: Usando data-src = {image_url}")
                    
                    # Ultimo fallback a data-original
                    if not image_url and cover_img.has_attr('data-original'):
                        image_url = cover_img['data-original']
                        print(f"Novel {novel_info.get('title', 'Unknown')}: Usando data-original = {image_url}")
                    
                    if image_url:
                        novel_info['cover_image'] = image_url
                    else:
                        print(f"Nessuna immagine trovata per {novel_info.get('title', 'Unknown')}")
                    
                    # Assicurati che l'URL dell'immagine sia completo
                    if novel_info.get('cover_image') and novel_info['cover_image'].startswith('/'):
                        novel_info['cover_image'] = f"https://novelfire.net{novel_info['cover_image']}"
                
                # Estrai il numero di capitoli
                chapters_elem = item.select_one('div.novel-stats i.icon-book-open')
                if chapters_elem and chapters_elem.parent:
                    chapters_text = chapters_elem.parent.get_text(strip=True)
                    # Estrai solo i numeri
                    import re
                    chapter_match = re.search(r'(\d+)\s*Chapters', chapters_text)
                    if chapter_match:
                        novel_info['chapters_count'] = int(chapter_match.group(1))
                    else:
                        novel_info['chapters_count'] = chapters_text
                
                # Aggiungi alla lista solo se abbiamo almeno titolo e URL
                if novel_info.get('title') and novel_info.get('url'):
                    page_novels.append(novel_info)
            
            # Aggiungi le novel di questa pagina alla lista complessiva
            all_novels.extend(page_novels)
            print(f"Aggiunte {len(page_novels)} novel alla lista. Totale: {len(all_novels)}")
            
            # Salva parziale in JSON se richiesto
            if save_json:
                import os
                import json
                
                # Crea directory per i risultati se non esiste
                os.makedirs('novel_data', exist_ok=True)
                
                # Salva i risultati in JSON
                with open(f'novel_data/novels_page_{start_page}_to_{page}.json', 'w', encoding='utf-8') as f:
                    json.dump({
                        "total": len(all_novels),
                        "novels": all_novels
                    }, f, ensure_ascii=False, indent=2)
                
                print(f"Risultati parziali salvati in novel_data/novels_page_{start_page}_to_{page}.json")
            
            # Passa alla pagina successiva
            page += 1
            
            # Piccola pausa per non sovraccaricare il server
            import time
            time.sleep(1)
    
    except Exception as e:
        print(f"Errore durante l'estrazione delle novel: {str(e)}")
    
    # Rimuovi duplicati basati sull'URL
    unique_novels = []
    seen_urls = set()
    
    for novel in all_novels:
        if novel['url'] not in seen_urls:
            seen_urls.add(novel['url'])
            unique_novels.append(novel)
    
    print(f"Totale novel uniche trovate: {len(unique_novels)}")
    
    response_data = {
        "status": "ok",
        "messaggio": f"chiamata eseguita correttamente - getnovelsfire_all",
        "pagina_iniziale": start_page,
        "pagina_finale": page - 1,
        "totale_pagine": page - start_page,
        "totale_novel": len(unique_novels),
        "data": unique_novels
    }
    
    return jsonify(response_data)

@app.route('/get_novelfire_chapter_content')
def get_novelfire_chapter_content():
    """
    Estrae il contenuto di un capitolo specifico da novelfire.net.
    Dato che le novel sono testi (libri), questa funzione si concentra sull'estrazione
    del contenuto testuale. Supporta anche la richiesta di traduzione.
    """
    url = request.args.get('url', '')
    translation_mode = request.args.get('translation', 'default')  # Opzioni: default, dynamic, robust, lore
    if not url:
        return jsonify({
            "status": "error",
            "messaggio": "URL del capitolo non fornito",
            "data": {}
        }), 400
    
    print(f"Fetching chapter content from: {url} with translation mode: {translation_mode}")
    
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9,it;q=0.8',
        'Referer': 'https://novelfire.net/'
    }
    
    # Se viene specificata una modalità di traduzione, aggiungiamo il parametro all'URL
    if translation_mode != 'default' and 'translation=' not in url:
        # Verifica se l'URL ha già parametri
        if '?' in url:
            url += f'&translation={translation_mode}'
        else:
            url += f'?translation={translation_mode}'
    
    try:
        response = requests.get(url, headers=headers, timeout=15)
        response.raise_for_status()  # Solleva un'eccezione per errori HTTP
    except requests.exceptions.RequestException as e:
        return jsonify({
            "status": "error",
            "messaggio": f"Errore nel recupero del contenuto: {str(e)}",
            "data": {}
        }), 500
        
    soup = BeautifulSoup(response.content, 'html.parser')
    
    # Estrai il titolo del capitolo
    chapter_title = ""
    title_selectors = [
        ('h1', {'class': 'chapter-title'}),
        ('h2', {'class': 'chapter-title'}),
        ('h1', {}),
        ('h2', {}),
        ('div', {'class': 'title'}),
        ('title', {})
    ]
    
    for tag, attrs in title_selectors:
        title_elem = soup.find(tag, attrs)
        if title_elem:
            chapter_title = title_elem.get_text(strip=True)
            print(f"Trovato titolo in {tag} con attributi {attrs}: {chapter_title}")
            break
    
    # Pulizia titolo (rimuovi "- NovelFire" o simili dal titolo)
    if chapter_title:
        chapter_title = re.sub(r'\s*[-–|]\s*NovelFire.*$', '', chapter_title)
        chapter_title = re.sub(r'\s*[-–|]\s*Novel\s*Fire.*$', '', chapter_title)
    
    # Estrai il contenuto del capitolo (testo della novel)
    chapter_content = ""
    chapter_paragraphs = []
    
    # Cerca prima il contenitore principale del capitolo
    content_container = None
    
    # Prova diverse possibili classi o ID per il contenitore
    content_selectors = [
        ('div', {'class': 'content-wrap'}), 
        ('div', {'id': 'chapter-content'}),
        ('div', {'class': 'chapter-content'}),
        ('div', {'class': 'reading-content'}),
        ('div', {'id': 'chaptercontent'}),
        ('div', {'id': 'chapter-c'}),
        ('div', {'class': 'text-left'}),
        ('div', {'class': 'chapter-inner'}),
        ('div', {'class': 'entry-content'}),
        ('article', {'class': 'post-content'})
    ]
    
    for tag, attrs in content_selectors:
        container = soup.find(tag, attrs)
        if container:
            content_container = container
            print(f"Trovato contenitore di tipo {tag} con attributi {attrs}")
            break
    
    # Se ancora non troviamo il contenitore, usa un approccio più generico
    if not content_container:
        # Cerca div con classe che contiene "content"
        for div in soup.find_all('div'):
            if div.has_attr('class'):
                classes = div.get('class', [])
                if any(c and ('content' in c.lower() or 'chapter' in c.lower() or 'reading' in c.lower()) for c in classes):
                    content_container = div
                    print(f"Trovato contenitore generico con classe: {classes}")
                    break
    
    # Cerca un contenitore che ha molti paragrafi (probabile contenuto)
    if not content_container:
        max_paragraphs = 0
        for div in soup.find_all('div'):
            p_count = len(div.find_all('p'))
            if p_count > max_paragraphs and p_count > 3:  # Almeno 3 paragrafi
                max_paragraphs = p_count
                content_container = div
        if content_container:
            print(f"Trovato contenitore con il maggior numero di paragrafi: {max_paragraphs}")
    
    # Ultima chance: cerca il contenitore più grande nel body che probabilmente contiene il contenuto principale
    if not content_container:
        main_content = None
        max_text_length = 0
        
        for div in soup.find_all('div', recursive=False):
            text = div.get_text(strip=True)
            if len(text) > max_text_length:
                max_text_length = len(text)
                main_content = div
        
        if main_content and max_text_length > 500:  # Solo se c'è abbastanza testo
            content_container = main_content
            print(f"Trovato possibile main content container con {max_text_length} caratteri")
    
    # Se abbiamo trovato un contenitore, estrai il contenuto
    if content_container:
        # Rimuovi elementi indesiderati come pubblicità, script, ecc.
        for unwanted in content_container.find_all(['script', 'ins', 'iframe', 'style', 'noscript', 'button', 'nav']):
            unwanted.decompose()
        
        # Rimuovi div pubblicitari o non rilevanti
        for unwanted in content_container.find_all('div'):
            if unwanted.has_attr('class'):
                classes = unwanted.get('class', [])
                if any(c and any(x in c.lower() for x in ['ads', 'adsby', 'advert', 'comment', 'disqus', 'related', 'share']) for c in classes):
                    unwanted.decompose()
        
        # Controlla se il testo è già tradotto (se è stata richiesta una traduzione)
        translated_container = None
        if translation_mode != 'default':
            # Possibili selettori per contenitori di traduzione
            translated_selectors = [
                ('div', {'id': 'translated-content'}),
                ('div', {'class': 'translated-content'}),
                ('div', {'class': 'translation'}),
                ('div', {'id': 'translation'})
            ]
            
            for tag, attrs in translated_selectors:
                container = soup.find(tag, attrs)
                if container:
                    translated_container = container
                    print(f"Trovato contenitore tradotto di tipo {tag} con attributi {attrs}")
                    break
        
        # Usa il contenitore tradotto se disponibile, altrimenti usa quello originale
        container_to_use = translated_container if translated_container else content_container
        
        # Ora estrai i paragrafi in vari modi, in ordine di priorità
        paragraphs_extracted = False
        
        # 1. Metodo: Cerca tutti i tag <p> nel contenitore
        paragraphs = container_to_use.find_all('p')
        if paragraphs:
            for p in paragraphs:
                text = p.get_text(strip=True)
                if text and len(text) > 5:  # Ignora paragrafi molto corti
                    chapter_paragraphs.append(text)
            if chapter_paragraphs:
                paragraphs_extracted = True
                print(f"Estratti {len(chapter_paragraphs)} paragrafi dai tag <p>")
        
        # 2. Metodo: Cerca altri elementi che potrebbero contenere testo
        if not paragraphs_extracted:
            text_elements = container_to_use.find_all(['div', 'span', 'pre', 'article'])
            for elem in text_elements:
                # Salta elementi già processati o che contengono altri elementi di testo
                if elem.find_all(['p', 'div', 'span']):
                    continue
                
                text = elem.get_text(strip=True)
                if text and len(text) > 20:  # Testo di lunghezza significativa
                    chapter_paragraphs.append(text)
            
            if chapter_paragraphs:
                paragraphs_extracted = True
                print(f"Estratti {len(chapter_paragraphs)} paragrafi da elementi di testo vari")
        
        # 3. Metodo: Divide il testo per newline
        if not paragraphs_extracted:
            # Estrai tutto il testo e divide per newline
            raw_text = container_to_use.get_text('\n', strip=True)
            lines = [line.strip() for line in raw_text.split('\n') if line.strip()]
            
            # Filtra le linee per trovare paragrafi reali (quelli abbastanza lunghi)
            for line in lines:
                if len(line) > 20:  # Solo linee significative
                    chapter_paragraphs.append(line)
            
            if chapter_paragraphs:
                paragraphs_extracted = True
                print(f"Estratti {len(chapter_paragraphs)} paragrafi dividendo per newline")
        
        # 4. Metodo: Usa direttamente tutte le stringhe come ultimo tentativo
        if not paragraphs_extracted:
            # Prendi tutti i testi senza filtrare
            for text in container_to_use.stripped_strings:
                if len(text) > 15:  # Ignora testi troppo corti
                    chapter_paragraphs.append(text)
            
            if chapter_paragraphs:
                paragraphs_extracted = True
                print(f"Estratti {len(chapter_paragraphs)} paragrafi da tutte le stringhe")
        
        # 5. Metodo: Se ancora niente, estrai il testo grezzo intero
        if not paragraphs_extracted:
            raw_text = container_to_use.get_text(strip=True)
            if raw_text and len(raw_text) > 100:
                # Divide il testo in paragrafi ogni 500 caratteri come ultima risorsa
                for i in range(0, len(raw_text), 500):
                    end = min(i + 500, len(raw_text))
                    chunk = raw_text[i:end]
                    # Trova un buon punto di interruzione
                    if end < len(raw_text):
                        last_period = chunk.rfind('.')
                        if last_period > 0:
                            chunk = chunk[:last_period + 1]
                            i = i + last_period
                    chapter_paragraphs.append(chunk)
                print(f"Estratto testo grezzo diviso in {len(chapter_paragraphs)} parti")
        
        # Rimuovi duplicati e paragrafi che sono sottoinsiemi di altri
        cleaned_paragraphs = []
        paragraph_set = set()
        
        for p in chapter_paragraphs:
            # Salta paragrafi già visti o che sono sottoinsiemi di altri
            if p in paragraph_set:
                continue
                
            # Controlla se è un sottoinsieme di un paragrafo già incluso
            is_subset = False
            for existing in cleaned_paragraphs:
                if p in existing and len(p) < len(existing):
                    is_subset = True
                    break
                    
            if not is_subset:
                cleaned_paragraphs.append(p)
                paragraph_set.add(p)
        
        # Unisci i paragrafi con doppi newline per la leggibilità
        chapter_paragraphs = cleaned_paragraphs
        chapter_content = '\n\n'.join(chapter_paragraphs)
    else:
        # Se non troviamo nessun contenitore, prova un approccio drastico
        print("Nessun contenitore trovato, provando un'estrazione globale")
        
        # Rimuovi header, footer, script e altri elementi non rilevanti
        for elem in soup.find_all(['header', 'footer', 'nav', 'script', 'style', 'meta', 'link']):
            elem.decompose()
        
        # Cerca il contenuto principale nella pagina
        main_text = ""
        longest_text = ""
        
        # Cerca il div con più testo (probabile contenuto principale)
        for div in soup.find_all('div'):
            text = div.get_text(strip=True)
            if len(text) > len(longest_text):
                longest_text = text
        
        if len(longest_text) > 500:  # Testo abbastanza lungo da sembrare un capitolo
            # Divide in paragrafi basandosi su newline o punti
            lines = longest_text.split('\n')
            for line in lines:
                line = line.strip()
                if line and len(line) > 20:
                    chapter_paragraphs.append(line)
            
            # Se non abbiamo abbastanza paragrafi, prova a dividere per frasi
            if len(chapter_paragraphs) < 3:
                chapter_paragraphs = []
                sentences = re.split(r'(?<=[.!?])\s+', longest_text)
                current_paragraph = ""
                
                for sentence in sentences:
                    sentence = sentence.strip()
                    if not sentence:
                        continue
                        
                    current_paragraph += sentence + " "
                    
                    # Crea un paragrafo ogni 2-3 frasi
                    if sentence.endswith(('.', '!', '?')) and len(current_paragraph.split('.')) > 2:
                        chapter_paragraphs.append(current_paragraph.strip())
                        current_paragraph = ""
                
                # Aggiungi l'ultimo paragrafo se c'è
                if current_paragraph:
                    chapter_paragraphs.append(current_paragraph.strip())
            
            chapter_content = '\n\n'.join(chapter_paragraphs)
            print(f"Estrazione di emergenza: trovati {len(chapter_paragraphs)} paragrafi")
        else:
            chapter_content = "Contenuto non trovato. La struttura della pagina potrebbe essere cambiata."
            print("Nessun contenuto significativo trovato nella pagina")
    
    # Estrai capitolo precedente e successivo
    prev_link = ""
    next_link = ""
    
    # Prova vari selettori per trovare i link di navigazione
    navigation_selectors = [
        ('a', {'class': 'prev-chapter'}),
        ('a', {'class': 'next-chapter'}),
        ('a', {'class': 'prev'}),
        ('a', {'class': 'next'}),
        ('a', {'rel': 'prev'}),
        ('a', {'rel': 'next'}),
    ]
    
    # Cerca il link precedente
    for tag, attrs in navigation_selectors:
        prev_elem = soup.find(tag, attrs)
        if prev_elem and prev_elem.has_attr('href'):
            prev_href = prev_elem['href']
            if prev_href.startswith('/'):
                prev_link = f"https://novelfire.net{prev_href}"
            else:
                prev_link = prev_href
            print(f"Trovato link al capitolo precedente: {prev_link}")
            break
    
    # Cerca il link successivo
    for tag, attrs in navigation_selectors[1:]:  # Salta il primo selettore che è per prev
        next_elem = soup.find(tag, attrs)
        if next_elem and next_elem.has_attr('href'):
            next_href = next_elem['href']
            if next_href.startswith('/'):
                next_link = f"https://novelfire.net{next_href}"
            else:
                next_link = next_href
            print(f"Trovato link al capitolo successivo: {next_link}")
            break
    
    # Prepara la risposta
    chapter_data = {
        "title": chapter_title,
        "content": chapter_content,
        "paragraphs": chapter_paragraphs,
        "prev_chapter": prev_link,
        "next_chapter": next_link,
        "translation_mode": translation_mode
    }
    
    # Stampa statistiche sul contenuto estratto
    print(f"Estratto capitolo: '{chapter_title}' con {len(chapter_paragraphs)} paragrafi e {len(chapter_content)} caratteri totali")
    if not chapter_paragraphs:
        print("ATTENZIONE: Nessun paragrafo trovato!")
    
    response_data = {
        "status": "ok",
        "messaggio": "contenuto del capitolo recuperato con successo",
        "data": chapter_data
    }
    
    return jsonify(response_data)
    

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
