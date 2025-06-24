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
            result_list.append({'title': item.text.strip(), 'link': item.get('href')})
                
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
            href = last_page_element.get('href', '')
            match = re.search(r'/(\d+)', href)
            if match:
                total_pages = int(match.group(1))
        
        # Se non riusciamo a trovare il totale, usa un valore di default
        if total_pages == 0:
            all_page_links = soup.select('li.page-item a.page-link')
            if all_page_links:
                total_pages = 10  # Default
            
        print(f"Totale pagine rilevate: {total_pages}")
            
        # Ottieni tutte le immagini
        for i in range(1, total_pages + 1):
            page_response = requests.get(f"{link}/{i}")
            if page_response.status_code == 200:
                page_soup = BeautifulSoup(page_response.content, 'html.parser')
                img_element = page_soup.select_one('img.chapter-img')
                if img_element and img_element.get('src'):
                    linkLetturaCapitolo.append(img_element['src'])
    
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
    page_link = None
    if response.status_code == 200:
        soup = BeautifulSoup(response.content, 'html.parser')
        # Cerca il numero dell'ultima pagina disponibile in modo più robusto
        last_page = 1
        pagination = soup.find_all('li', {'class': 'page-item last'})
        for item in pagination:
            page_link = item.find('a')
            if page_link:
                href = page_link.get('href', '')
                match = re.search(r'page=(\d+)', href)
                if match:
                    last_page = int(match.group(1))
                    
    all_manga = []
    for page_num in range(1, last_page + 1):
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
        "messaggio": f"chiamata eseguita correttamente - all manga",
        "pagina": page_link,
        "data": all_manga,
    }
    return jsonify(response_data)

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
        for current_page in range(page, page + max_pages):
            current_url = novels_url
            if current_page > 1:
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
            
            # Trova il contenitore principale delle novel
            novel_list_div = soup.find('div', {'id': 'list-novel'})
            novel_items = []
            
            if novel_list_div:
                novel_lists = novel_list_div.find_all('ul', {'class': 'novel-list'})
                for novel_list in novel_lists:
                    items = novel_list.find_all('li', {'class': 'novel-item'})
                    novel_items.extend(items)
            
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
                    if novel_info['url'] and novel_info['url'].startswith('/'):
                        novel_info['url'] = f"{base_url}{novel_info['url']}"
                
                # Estrai l'immagine di copertina
                cover_img = item.select_one('figure.novel-cover img')
                if cover_img:
                    image_url = None
                    
                    if cover_img.has_attr('src') and not cover_img['src'].startswith('data:'):
                        image_url = cover_img['src']
                    
                    if not image_url and cover_img.has_attr('data-src'):
                        image_url = cover_img['data-src']
                    
                    if not image_url and cover_img.has_attr('data-original'):
                        image_url = cover_img['data-original']
                    
                    if image_url:
                        novel_info['cover_image'] = image_url
                        if novel_info['cover_image'].startswith('/'):
                            novel_info['cover_image'] = f"https://novelfire.net{novel_info['cover_image']}"
                
                # Estrai il numero di capitoli
                chapters_elem = item.select_one('div.novel-stats i.icon-book-open')
                if chapters_elem and chapters_elem.parent:
                    chapters_text = chapters_elem.parent.get_text(strip=True)
                    chapter_match = re.search(r'(\d+)\s*Chapters', chapters_text)
                    if chapter_match:
                        novel_info['chapters_count'] = int(chapter_match.group(1))
                    else:
                        novel_info['chapters_count'] = chapters_text
                
                # Aggiungi alla lista solo se abbiamo almeno titolo e URL
                if novel_info.get('title') and novel_info.get('url'):
                    novels_list.append(novel_info)
            
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
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9,it;q=0.8',
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
    """
    url = request.args.get('url', '')
    translation_mode = request.args.get('translation', 'default')
    
    if not url:
        return jsonify({
            "status": "error",
            "messaggio": "URL del capitolo non fornito",
            "data": {}
        }), 400
    
    print(f"Fetching chapter content from: {url}")
    
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9,it;q=0.8',
        'Referer': 'https://novelfire.net/'
    }
    
    # Aggiunge traduzione se richiesta
    if translation_mode != 'default' and 'translation=' not in url:
        if '?' in url:
            url += f'&translation={translation_mode}'
        else:
            url += f'?translation={translation_mode}'
    
    try:
        response = requests.get(url, headers=headers, timeout=15)
        response.raise_for_status()
    except requests.exceptions.RequestException as e:
        return jsonify({
            "status": "error",
            "messaggio": f"Errore nel recupero del contenuto: {str(e)}",
            "data": {}
        }), 500
        
    soup = BeautifulSoup(response.content, 'html.parser')
    
    # Estrai il titolo del capitolo
    chapter_title = ""
    title_elem = soup.find(['h1', 'h2'], {'class': 'chapter-title'})
    if title_elem:
        chapter_title = title_elem.get_text(strip=True)
    else:
        title_elem = soup.find('title')
        if title_elem:
            chapter_title = title_elem.get_text(strip=True)
    
    # Pulisci il titolo
    if chapter_title:
        chapter_title = re.sub(r'\s*[-–|]\s*NovelFire.*$', '', chapter_title)
    
    # Estrai il contenuto del capitolo
    chapter_content = ""
    chapter_paragraphs = []
    content_container = None
    
    # Selettori per il contenitore principale
    content_selectors = [
        ('div', {'class': 'content-wrap'}),
        ('div', {'id': 'chapter-content'}),
        ('div', {'class': 'chapter-content'}),
        ('div', {'class': 'reading-content'}),
        ('div', {'id': 'chaptercontent'}),
        ('div', {'id': 'chapter-c'})
    ]
    
    # Cerca il contenitore
    for tag, attrs in content_selectors:
        container = soup.find(tag, attrs)
        if container:
            content_container = container
            break
    
    # Fallback: cerca div con più paragrafi
    if not content_container:
        max_paragraphs = 0
        for div in soup.find_all('div'):
            p_count = len(div.find_all('p'))
            if p_count > max_paragraphs and p_count > 2:
                max_paragraphs = p_count
                content_container = div
    
    # Fallback: cerca div con più testo
    if not content_container:
        max_text_length = 0
        for div in soup.find_all('div'):
            text = div.get_text(strip=True)
            if len(text) > max_text_length and len(text) > 500:
                max_text_length = len(text)
                content_container = div
    
    if content_container:
        # Rimuovi elementi indesiderati
        for unwanted in content_container.find_all(['script', 'style', 'ins', 'iframe', 'nav', 'header', 'footer']):
            unwanted.decompose()
        
        # Metodo 1: Estrai paragrafi dai tag <p>
        paragraphs = content_container.find_all('p')
        if paragraphs:
            for p in paragraphs:
                text = p.get_text(strip=True)
                if text and len(text) > 10:
                    chapter_paragraphs.append(text)
        
        # Metodo 2: Se non ci sono paragrafi, dividi per newline
        if not chapter_paragraphs:
            raw_text = content_container.get_text('\n', strip=True)
            lines = [line.strip() for line in raw_text.split('\n') if line.strip()]
            for line in lines:
                if len(line) > 15:
                    chapter_paragraphs.append(line)
        
        # Metodo 3: Ultima risorsa - tutte le stringhe
        if not chapter_paragraphs:
            for text in content_container.stripped_strings:
                if len(text) > 15:
                    chapter_paragraphs.append(text)
        
        chapter_content = '\n\n'.join(chapter_paragraphs)
    else:
        chapter_content = "Contenuto non trovato. La struttura della pagina potrebbe essere cambiata."
    
    # Estrai link ai capitoli precedente e successivo
    prev_link = ""
    next_link = ""
    
    prev_elem = soup.find('a', {'class': 'prev-chapter'}) or soup.find('a', text=lambda t: t and 'Previous' in str(t))
    next_elem = soup.find('a', {'class': 'next-chapter'}) or soup.find('a', text=lambda t: t and 'Next' in str(t))
    
    if prev_elem and prev_elem.has_attr('href'):
        prev_href = prev_elem['href']
        if prev_href.startswith('/'):
            prev_link = f"https://novelfire.net{prev_href}"
        else:
            prev_link = prev_href
    
    if next_elem and next_elem.has_attr('href'):
        next_href = next_elem['href']
        if next_href.startswith('/'):
            next_link = f"https://novelfire.net{next_href}"
        else:
            next_link = next_href
    
    # Prepara la risposta
    chapter_data = {
        "title": chapter_title,
        "content": chapter_content,
        "paragraphs": chapter_paragraphs,
        "prev_chapter": prev_link,
        "next_chapter": next_link,
        "translation_mode": translation_mode
    }
    
    print(f"Estratto capitolo: '{chapter_title}' con {len(chapter_paragraphs)} paragrafi")
    
    response_data = {
        "status": "ok",
        "messaggio": "contenuto del capitolo recuperato con successo",
        "data": chapter_data
    }
    
    return jsonify(response_data)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
