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

@app.route('/get_all_webnovels')
def get_all_webnovels():
    # URL fisso come da richiesta
    url = "https://www.webnovel.com/search?keywords=light+novels&type=novel"
    
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    
    try:
        response = requests.get(url, headers=headers)
        novels = []
        
        if response.status_code == 200:
            soup = BeautifulSoup(response.content, 'html.parser')
            
            # Cerca gli elementi con la classe 'g_thumb _xs pa l0 oh' come specificato
            thumb_elements = soup.select('div.g_thumb._xs.pa.l0.oh, a.g_thumb._xs.pa.l0.oh')
            
            for thumb_element in thumb_elements:
                novel = {}
                
                # Verifica se l'elemento è già un link o se dobbiamo cercare il parent
                if thumb_element.name == 'a':
                    a_element = thumb_element
                else:
                    a_element = thumb_element.find_parent('a') or thumb_element.select_one('a')
                
                if a_element:
                    # Estrai l'href
                    href = a_element.get('href')
                    if href:
                        novel['url'] = f"https://www.webnovel.com{href}" if not href.startswith('http') else href
                    
                    # Estrai il titolo dall'attributo title
                    title = a_element.get('title')
                    if title:
                        novel['title'] = title
                
                # Estrazione dell'immagine all'interno dell'elemento thumb
                img_element = thumb_element.select_one('img')
                if img_element:
                    src = img_element.get('src')
                    if src:
                        novel['cover_image'] = f"https:{src}" if src.startswith('//') else src
                
                # Cerca anche di estrarre l'ID del libro se disponibile
                if a_element:
                    book_id = a_element.get('data-bid')
                    if book_id:
                        novel['book_id'] = book_id
                
                # Se non abbiamo trovato il titolo nell'elemento a, cerchiamo altri elementi
                if not novel.get('title'):
                    # Cerchiamo titoli nelle vicinanze
                    parent = thumb_element.find_parent('li') or thumb_element.find_parent()
                    if parent:
                        title_element = parent.select_one('h3') or parent.select_one('.c_000')
                        if title_element:
                            novel['title'] = title_element.get_text().strip()
                
                # Estrazione dei tag se disponibili
                parent_li = thumb_element.find_parent('li')
                if parent_li:
                    tags = []
                    tag_elements = parent_li.select('p.mb8_g_tags a')
                    for tag_element in tag_elements:
                        tag = {
                            'name': tag_element.get_text().strip(),
                            'url': tag_element.get('href'),
                            'title': tag_element.get('title')
                        }
                        tags.append(tag)
                    
                    if tags:
                        novel['tags'] = tags
                    
                    # Valutazione (p.g_star_num)
                    rating_element = parent_li.select_one('p.g_star_num')
                    if rating_element:
                        novel['rating'] = rating_element.get_text().strip()
                
                # Verifica che abbiamo almeno URL e copertina (il titolo potrebbe mancare)
                if novel.get('url') and novel.get('cover_image'):
                    novels.append(novel)
            
            response_data = {
                "status": "ok",
                "data": novels
            }
        else:
            response_data = {
                "status": "error",
                "messaggio": f"Errore nella richiesta: {response.status_code}"
            }
    
    except Exception as e:
        response_data = {
            "status": "error",
            "messaggio": f"Errore: {str(e)}"
        }
    
    return jsonify(response_data)


#TODO: da camiare web di fireimento e fare su 


@app.route('/get_webnovel_chapters')
def get_webnovel_chapters():
    link = request.args.get('url', '')
    if not link or not link.startswith(('http://', 'https://')):
        return jsonify({
            "status": "error",
            "messaggio": "URL mancante o non valido",
            "data": []
        })
    
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml',
        'Accept-Language': 'en-US,en;q=0.9',
        'Referer': 'https://www.webnovel.com/'
    }
    
    try:
        # Add timeout to prevent hanging requests
        response = requests.get(link, headers=headers, timeout=10)
        chapters = []
        
        if response.status_code == 200:
            soup = BeautifulSoup(response.content, 'html.parser')
            
            # Expanded selector list to cover more website structures
            chapter_selectors = [
                'li.g_col_6', 
                'ul.content-list li', 
                'div.volume-item ol li',
                'div.chapter-list li',
                'ol.chapter-list li',
                'div.chapter-item',
                'a.chapter-link',
                'div.catalog-content-wrap a',
                'table.chapter-table tr'
            ]
            
            chapter_elements = soup.select(', '.join(chapter_selectors))
            
            print(f"Found {len(chapter_elements)} potential chapter elements")
            
            # If no chapters found with specific selectors, try a more generic approach
            if len(chapter_elements) == 0:
                # Look for any links that might contain 'chapter' in their text or attributes
                chapter_elements = soup.find_all('a', href=lambda href: href and ('chapter' in href.lower() or 'read' in href.lower()))
                print(f"Fallback search found {len(chapter_elements)} potential chapter links")
            
            for chapter_element in chapter_elements:
                # If the element is already an 'a' tag, use it directly
                if chapter_element.name == 'a':
                    a_element = chapter_element
                else:
                    # Try different ways to find the link element
                    a_element = (chapter_element.select_one('a.c_000') or 
                                chapter_element.select_one('a.chapter-item') or 
                                chapter_element.select_one('a[href*=chapter]') or
                                chapter_element.select_one('a'))
                
                if a_element:
                    # Get title from multiple possible sources
                    title = a_element.get('title') or a_element.get_text().strip()
                    
                    # Get href if it exists
                    href = a_element.get('href')
                    if href:
                        # Process href to ensure it's a complete URL
                        if href.startswith(('http://', 'https://')):
                            full_url = href
                        elif href.startswith('//'):
                            full_url = f"https:{href}"
                        elif href.startswith('/'):
                            # Extract domain from original link
                            from urllib.parse import urlparse
                            parsed_uri = urlparse(link)
                            domain = f'{parsed_uri.scheme}://{parsed_uri.netloc}'
                            full_url = f"{domain}{href}"
                        else:
                            full_url = f"https://www.webnovel.com/{href}"
                    else:
                        continue  # Skip if no href found
                    
                    # Try to get chapter ID
                    chapter_id = (chapter_element.get('data-report-cid') or 
                                a_element.get('data-report-cid') or 
                                a_element.get('data-cid') or
                                a_element.get('id') or
                                '')
                    
                    # Extract chapter number from URL or title if possible
                    import re
                    chapter_num_match = re.search(r'chapter[_\-\s]*(\d+)', full_url.lower() + ' ' + title.lower())
                    chapter_num = chapter_num_match.group(1) if chapter_num_match else None
                    
                    # Only add if we have at least a title and URL
                    if title and href:
                        chapter_info = {
                            'title': title,
                            'url': full_url,
                            'id': chapter_id,
                            'chapter_num': chapter_num
                        }
                        chapters.append(chapter_info)
            
            # Sort chapters by chapter number if available
            if chapters and all(ch.get('chapter_num') is not None for ch in chapters):
                chapters.sort(key=lambda x: int(x['chapter_num']) if x['chapter_num'] else 0)
            
            response_data = {
                "status": "ok" if chapters else "warning",
                "messaggio": f"Trovati {len(chapters)} capitoli da {link}",
                "data": chapters
            }
        else:
            response_data = {
                "status": "error",
                "messaggio": f"Errore nella richiesta: status code {response.status_code}",
                "data": []
            }
    
    except requests.exceptions.Timeout:
        response_data = {
            "status": "error",
            "messaggio": "Timeout durante la richiesta alla pagina web",
            "data": []
        }
    except requests.exceptions.RequestException as e:
        response_data = {
            "status": "error",
            "messaggio": f"Errore di rete: {str(e)}",
            "data": []
        }
    except Exception as e:
        response_data = {
            "status": "error",
            "messaggio": f"Errore generico: {str(e)}",
            "data": []
        }
    
    return jsonify(response_data)
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
