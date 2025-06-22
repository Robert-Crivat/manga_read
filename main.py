from flask import Flask, request, jsonify
from flask_cors import CORS
import requests
import re
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
    
    # Rimuovi duplicati se necessario (basati sull'URL)
    seen_urls = set()
    unique_novels = []
    for novel in novels_list:
        if novel['url'] not in seen_urls:
            seen_urls.add(novel['url'])
            unique_novels.append(novel)
    
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

@app.route('/getnovel/<slug>')
def getnovel(slug):
    url = f'https://www.wuxiaworld.com/novel/{slug}'
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    response = requests.get(url, headers=headers)
    novel_info = {}
    
    if response.status_code == 200:
        soup = BeautifulSoup(response.content, 'html.parser')
        
        # Estrai titolo principale
        title_elem = soup.select_one('h1, .novel-title, .novel-name')
        if title_elem:
            novel_info['title'] = title_elem.text.strip()
        
        # Estrai immagine di copertina
        cover_img = soup.select_one('img.novel-cover, img.cover-image')
        if cover_img:
            novel_info['cover_image'] = cover_img.get('src', '')
        
        # Estrai descrizione
        desc_elem = soup.select_one('div.novel-description, div.synopsis')
        if desc_elem:
            novel_info['description'] = desc_elem.text.strip()
        
        # Estrai capitoli
        chapters = []
        chapter_elements = soup.select('li.chapter, li.chapter-item')
        for chapter in chapter_elements:
            chapter_info = {}
            link = chapter.select_one('a')
            if link:
                chapter_info['title'] = link.text.strip()
                chapter_info['url'] = 'https://www.wuxiaworld.com' + link.get('href', '')
                chapters.append(chapter_info)
        
        novel_info['chapters'] = chapters
        novel_info['total_chapters'] = len(chapters)
        novel_info['url'] = url
        
        response_data = {
            "status": "ok",
            "messaggio": f"chiamata eseguita correttamente - getnovel({slug})",
            "data": novel_info
        }
        
        return jsonify(response_data)
    else:
        return jsonify({
            "status": "error",
            "messaggio": f"Errore nella richiesta: {response.status_code}",
            "data": None
        })

@app.route('/getchapter/<slug>/<chapter_id>')
def getchapter(slug, chapter_id):
    """
    Estrae il contenuto di un capitolo specifico di una novel da wuxiaworld.com.
    
    Parameters:
    - slug: L'identificativo della novel (es. 'reborn-apocalypse')
    - chapter_id: L'identificativo del capitolo (es. 'chapter-3')
    
    Returns:
    - JSON con il contenuto del capitolo formattato
    """
    base_url = 'https://www.wuxiaworld.com'
    url = f'{base_url}/novel/{slug}/{chapter_id}'
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }
    
    # Prima prova con l'API GraphQL
    graphql_url = f"{base_url}/api/graphql"
    
    # Query GraphQL per ottenere il contenuto di un capitolo specifico
    graphql_query = """
    query ChapterContent($slug: String!, $chapterSlug: String!) {
      chapter(novelSlug: $slug, chapterSlug: $chapterSlug) {
        id
        name
        number
        content
        novel {
          name
          slug
        }
      }
    }
    """
    
    variables = {
        "slug": slug,
        "chapterSlug": chapter_id
    }
    
    chapter_info = {
        'title': '',
        'content': [],
        'novel_slug': slug,
        'chapter_id': chapter_id,
        'url': url
    }
    
    try:
        # Chiamata API GraphQL
        response = requests.post(
            graphql_url,
            json={'query': graphql_query, 'variables': variables},
            headers=headers
        )
        
        if response.status_code == 200:
            data = response.json()
            
            # Verifichiamo se abbiamo ricevuto dati validi
            if 'data' in data and 'chapter' in data['data'] and data['data']['chapter']:
                chapter_data = data['data']['chapter']
                
                # Estrai il titolo
                chapter_info['title'] = chapter_data.get('name', f"Chapter {chapter_data.get('number', '')}")
                
                # Estrai il contenuto
                content = chapter_data.get('content', '')
                if content:
                    # Dividi il contenuto in paragrafi
                    soup = BeautifulSoup(content, 'html.parser')
                    paragraphs = soup.find_all('p')
                    
                    if paragraphs:
                        for p in paragraphs:
                            text = p.text.strip()
                            if text:
                                chapter_info['content'].append(text)
                    else:
                        # Se non trova paragrafi, divide per \n o <br>
                        lines = content.split('\n')
                        for line in lines:
                            text = line.strip()
                            if text:
                                chapter_info['content'].append(text)
                
                # Se abbiamo ottenuto contenuto, restituisci subito la risposta
                if chapter_info['content']:
                    response_data = {
                        "status": "ok",
                        "messaggio": f"chiamata eseguita correttamente - getchapter({slug}/{chapter_id})",
                        "data": chapter_info
                    }
                    return jsonify(response_data)
    except Exception as e:
        print(f"Errore nella chiamata GraphQL per il capitolo: {str(e)}")
    
    # Se l'approccio GraphQL fallisce o non restituisce contenuto, usa l'approccio HTML
    try:
        response = requests.get(url, headers={
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        })
        
        if response.status_code == 200:
            html = response.text
            
            # Cerchiamo un pattern JSON nell'HTML che contenga i dati del capitolo
            import re
            json_pattern = r'__REACT_QUERY_STATE__\s*=\s*({.*?});'
            matches = re.search(json_pattern, html, re.DOTALL)
            
            if matches:
                json_str = matches.group(1)
                try:
                    # Puliamo e analizziamo il JSON
                    import json
                    data = json.loads(json_str)
                    
                    # Estraiamo i dati dal JSON se presente
                    if 'queries' in data:
                        for query in data['queries']:
                            if 'state' in query and 'data' in query['state']:
                                chapter_data = query['state']['data']
                                if chapter_data:
                                    # Cerca il titolo
                                    if 'name' in chapter_data:
                                        chapter_info['title'] = chapter_data['name']
                                    
                                    # Cerca il contenuto
                                    if 'content' in chapter_data:
                                        content = chapter_data['content']
                                        soup = BeautifulSoup(content, 'html.parser')
                                        paragraphs = soup.find_all('p')
                                        
                                        if paragraphs:
                                            for p in paragraphs:
                                                text = p.text.strip()
                                                if text:
                                                    chapter_info['content'].append(text)
                                        else:
                                            # Se non trova paragrafi, divide per \n o <br>
                                            lines = content.split('\n')
                                            for line in lines:
                                                text = line.strip()
                                                if text:
                                                    chapter_info['content'].append(text)
                except Exception as json_err:
                    print(f"Errore nell'analisi JSON per il capitolo: {str(json_err)}")
            
            # Se ancora non abbiamo contenuto, cerca nel DOM
            if not chapter_info['content']:
                soup = BeautifulSoup(response.content, 'html.parser')
                
                # Estrai il titolo del capitolo
                title_elem = soup.select_one('h4.chapter-title, h1.chapter-title, .novel-content h1, .chapter-header')
                if title_elem:
                    chapter_info['title'] = title_elem.text.strip()
                
                # Estrai il contenuto del capitolo
                content_elem = soup.select_one('div.chapter-content, div.fr-view, div.reader-content, .novel-content')
                
                if content_elem:
                    # Estrai tutti i paragrafi
                    paragraphs = content_elem.select('p')
                    for p in paragraphs:
                        text = p.text.strip()
                        if text:
                            chapter_info['content'].append(text)
                    
                    # Se non abbiamo paragrafi, prova a estrarre il testo direttamente
                    if not chapter_info['content']:
                        text = content_elem.get_text(separator='\n').strip()
                        lines = text.split('\n')
                        for line in lines:
                            clean_line = line.strip()
                            if clean_line:
                                chapter_info['content'].append(clean_line)
    except Exception as e:
        print(f"Errore nell'approccio HTML per il capitolo: {str(e)}")
    
    response_data = {
        "status": "ok",
        "messaggio": f"chiamata eseguita correttamente - getchapter({slug}/{chapter_id})",
        "data": chapter_info
    }
    
    return jsonify(response_data)

@app.route('/getchapters/<slug>')
def getchapters(slug):
    """
    Estrae tutti i capitoli disponibili per una novel specifica da wuxiaworld.com.
    
    Parameters:
    - slug: L'identificativo della novel (es. 'reborn-apocalypse')
    
    Returns:
    - JSON con l'elenco dei capitoli disponibili
    """
    # URL di base e headers
    base_url = 'https://www.wuxiaworld.com'
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }
    
    # Dato che il sito usa GraphQL, utilizziamo una query per ottenere i capitoli
    graphql_url = f"{base_url}/api/graphql"
    
    # Query GraphQL per ottenere i capitoli di una novel specifica
    graphql_query = """
    query NovelChapters($slug: String!) {
      novel(slug: $slug) {
        id
        name
        slug
        chaptersCount
        chapters {
          id
          name
          slug
          number
          publishDate
          chapterUrl
        }
      }
    }
    """
    
    variables = {
        "slug": slug
    }
    
    chapters_list = []
    
    try:
        # Chiamata API GraphQL
        response = requests.post(
            graphql_url,
            json={'query': graphql_query, 'variables': variables},
            headers=headers
        )
        
        print(f"Risposta GraphQL status: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            
            # Verifichiamo se abbiamo ricevuto dati validi
            if 'data' in data and 'novel' in data['data'] and data['data']['novel']:
                novel_data = data['data']['novel']
                chapters = novel_data.get('chapters', [])
                
                for chapter in chapters:
                    chapter_info = {
                        'title': chapter.get('name', f'Chapter {chapter.get("number", "")}'),
                        'chapter_id': chapter.get('slug', ''),
                        'url': chapter.get('chapterUrl', f"/novel/{slug}/{chapter.get('slug', '')}"),
                        'number': chapter.get('number', ''),
                        'date': chapter.get('publishDate', '')
                    }
                    
                    # Aggiungi il protocollo e dominio se l'URL è relativo
                    if chapter_info['url'].startswith('/'):
                        chapter_info['url'] = f"{base_url}{chapter_info['url']}"
                    
                    chapters_list.append(chapter_info)
                
                # Ordina i capitoli per numero/posizione se disponibile
                if chapters_list and 'number' in chapters_list[0]:
                    chapters_list.sort(key=lambda x: x.get('number', 0))
    except Exception as e:
        print(f"Errore nella chiamata GraphQL: {str(e)}")
    
    # Se l'approccio GraphQL fallisce, proviamo con l'approccio alternativo
    if not chapters_list:
        print("GraphQL fallito, provo approccio alternativo...")
        
        # Approccio alternativo: cercare di estrarre l'elenco dei capitoli dalla pagina HTML
        # Questa è una soluzione di fallback nel caso in cui l'API GraphQL cambi o non sia disponibile
        try:
            # URL della pagina della novel
            novel_url = f"{base_url}/novel/{slug}"
            response = requests.get(novel_url, headers={
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
            })
            
            if response.status_code == 200:
                html = response.text
                
                # Cerchiamo un pattern JSON nell'HTML che contenga i dati dei capitoli
                # Molti siti moderni caricano i dati iniziali come JSON nel codice HTML
                import re
                json_pattern = r'__REACT_QUERY_STATE__\s*=\s*({.*?});'
                matches = re.search(json_pattern, html, re.DOTALL)
                
                if matches:
                    json_str = matches.group(1)
                    try:
                        # Puliamo e analizziamo il JSON
                        import json
                        data = json.loads(json_str)
                        
                        # Estraiamo i dati dal JSON se presente
                        if 'queries' in data:
                            for query in data['queries']:
                                if 'state' in query and 'data' in query['state']:
                                    novel_data = query['state']['data']
                                    if novel_data and 'chapters' in novel_data:
                                        for chapter in novel_data['chapters']:
                                            chapter_info = {
                                                'title': chapter.get('name', f"Chapter {chapter.get('number', '')}"),
                                                'chapter_id': chapter.get('slug', ''),
                                                'url': f"{base_url}/novel/{slug}/{chapter.get('slug', '')}",
                                                'number': chapter.get('number', ''),
                                                'date': chapter.get('publishDate', '')
                                            }
                                            chapters_list.append(chapter_info)
                    except Exception as json_err:
                        print(f"Errore nell'analisi JSON: {str(json_err)}")
                        
                # Se ancora non abbiamo trovato capitoli, cerchiamo link nella pagina che potrebbero essere capitoli
                if not chapters_list:
                    soup = BeautifulSoup(response.content, 'html.parser')
                    
                    # Cerca i capitoli attraverso i vari possibili pattern di link
                    chapter_links = soup.select(f'a[href*="/novel/{slug}/chapter-"], a[href*="/novel/{slug}/book-"]')
                    
                    for link in chapter_links:
                        href = link.get('href', '')
                        if href:
                            # Estrai l'ID del capitolo dall'URL
                            chapter_id = href.split('/')[-1]
                            chapter_info = {
                                'title': link.text.strip() or f"Chapter {len(chapters_list) + 1}",
                                'chapter_id': chapter_id,
                                'url': href if href.startswith('http') else f"{base_url}{href}",
                            }
                            chapters_list.append(chapter_info)
        except Exception as e:
            print(f"Errore nell'approccio alternativo: {str(e)}")
    
    # Rimuovi eventuali duplicati basati sull'URL
    unique_chapters = []
    seen_urls = set()
    for chapter in chapters_list:
        if chapter['url'] not in seen_urls:
            seen_urls.add(chapter['url'])
            unique_chapters.append(chapter)
    
    response_data = {
        "status": "ok",
        "messaggio": f"chiamata eseguita correttamente - getchapters({slug})",
        "totale": len(unique_chapters),
        "data": unique_chapters
    }
    
    return jsonify(response_data)
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
