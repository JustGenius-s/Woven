/** Read advertised page artwork without executing any page scripts. */
export class VideoCoverMetadata {
  static imageFromHtml(html: string): string {
    const tags: RegExpMatchArray | null = html.match(/<meta\s[^>]*>/gi);
    let twitter: string = '';
    if (tags === null) {
      return '';
    }
    for (let index: number = 0; index < tags.length; index++) {
      const tag: string = tags[index];
      const name: string = (VideoCoverMetadata.attribute(tag, 'property') ||
        VideoCoverMetadata.attribute(tag, 'name')).toLowerCase();
      const content: string = VideoCoverMetadata.attribute(tag, 'content');
      if ((name === 'og:image' || name === 'og:image:secure_url') && content.length > 0) {
        return VideoCoverMetadata.decode(content);
      }
      if (name === 'twitter:image' || name === 'twitter:image:src') {
        twitter = VideoCoverMetadata.decode(content);
      }
    }
    return twitter;
  }

  private static attribute(tag: string, name: string): string {
    const pattern: RegExp = new RegExp(`\\s${name}\\s*=\\s*(?:"([^"]*)"|'([^']*)'|([^\\s>]+))`, 'i');
    const match: RegExpExecArray | null = pattern.exec(tag);
    return match === null ? '' : (match[1] ?? match[2] ?? match[3] ?? '');
  }

  private static decode(value: string): string {
    return value.replace(/&amp;/gi, '&').replace(/&quot;/gi, '"')
      .replace(/&#39;|&apos;/gi, "'").replace(/&lt;/gi, '<').replace(/&gt;/gi, '>');
  }
}
