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

@app.route('/search_manga')
def search_manga():
    keyword = request.args.get('keyword', '')
    response = requests.get('https://www.mangaworld.nz/archive?keyword=' + encode_keyword(keyword))
    result_list = []
    if response.status_code == 200:
        soup = BeautifulSoup(response.content, 'html.parser')
        Manga = soup.find_all('div', {'class': 'entry'})
        for item in Manga:
            link = re.search('href="(.+?)"', str(item)).group(1)
            src = re.search('src="(.+?)"', str(item)).group(1)
            alt = re.search('alt="(.+?)"', str(item)).group(1)
            result_list.append({'link': link, 'src': src, 'alt': alt})
    return jsonify(result_list)

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
    return jsonify(result_list)

@app.route('/chapter_pages')
def chapter_pages():
    link = request.args.get('link', '')
    status = requests.get(str(link) + '/1?style=list')
    linkLetturaCapitolo = []
    if status.status_code == 200:
        soup = BeautifulSoup(status.content, 'html.parser')
        n = 400
        for i in range(n+1):
            lettura = soup.find_all('img', {'id': 'page-'+str(i)})
            match = re.search(r'src="(.*)"', str(lettura))
            if match:
                src = match.group(1)
                linkLetturaCapitolo.append(src)
    return jsonify(linkLetturaCapitolo)

@app.route('/all_manga')
def all_manga():
    response = requests.get('https://www.mangaworld.nz/archive')
    # Find the pagination element to get the total number of pages
    last_page = 1  # Default to 1 in case we can't find pagination
    
    if response.status_code == 200:
        soup = BeautifulSoup(response.content, 'html.parser')
        pagination = soup.find('li', {'class': 'page-item last'})
        if pagination:
            page_link = pagination.find('a', {'class': 'page-link'})
            if page_link and page_link.text:
                try:
                    last_page = int(page_link.text)
                except ValueError:
                    pass  # If conversion fails, keep default value
                    
        linkLetturaCapitolo = []
        comics_grid = soup.find('div', {'class': 'comics-grid'})
        if comics_grid:
            Manga = comics_grid.find_all('div', {'class': 'entry'})
            for item in Manga:
                lettura = item.find('a', {'class': 'chap'})
                if lettura:
                    src = lettura.get('href')
                    if src:
                        src = remove_words_before_keyword(src, '/read/')
                        src = 'https://www.mangaworld.nz' + src
                        linkLetturaCapitolo.append(src)
    
    # Get all manga from all pages
    all_manga = []
    for page_num in range(1, last_page + 1):
        page_url = f'https://www.mangaworld.nz/archive?page={page_num}'
        page_response = requests.get(page_url)
        if page_response.status_code == 200:
            page_soup = BeautifulSoup(page_response.content, 'html.parser')
            comics_grid = page_soup.find('div', {'class': 'comics-grid'})
            manga_entries = []
            if comics_grid:
                manga_entries = comics_grid.find_all('div', {'class': 'entry'})
            
            for manga in manga_entries:
                manga_info = {}
                
                # Extract name
                name_elem = manga.find('h3', {'class': 'name m-0'})
                if name_elem:
                    manga_info['name'] = name_elem.text.strip()
                
                # Extract image
                thumb = manga.find('div', {'class': 'thumb position-relative'})
                if thumb:
                    img = thumb.find('img')
                    if img and img.get('src'):
                        manga_info['image'] = img.get('src')
                
                # Extract metadata
                genre_elem = manga.find('span', {'class': 'genre'})
                if genre_elem:
                    manga_info['genre'] = genre_elem.text.strip()
                
                status_elem = manga.find('span', {'class': 'status'})
                if status_elem:
                    manga_info['status'] = status_elem.text.strip()
                
                author_elem = manga.find('span', {'class': 'author'})
                if author_elem:
                    manga_info['author'] = author_elem.text.strip()
                
                artist_elem = manga.find('span', {'class': 'artist'})
                if artist_elem:
                    manga_info['artist'] = artist_elem.text.strip()
                
                genres_elem = manga.find('span', {'class': 'genres'})
                if genres_elem:
                    manga_info['genres'] = genres_elem.text.strip()
                
                story_elem = manga.find('div', {'class': 'd-none'})
                if story_elem:
                    manga_info['story'] = story_elem.text.strip()
                
                # Add to results
                all_manga.append(manga_info)
    
    return jsonify(all_manga)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
