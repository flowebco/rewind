'use strict';

const blogArticles = [
  {
    id: 'fluff-start',
    category: 'fluff',
    categoryLabel: 'فلاف پالپ',
    title: 'خط تولید فلاف پالپ از کجا شروع می‌شود؟',
    excerpt: 'پیش از انتخاب ماشین‌آلات، باید محصول موردنظر، ماده‌ی اولیه و محدودیت‌های پروژه را روشن کرد.',
    image: 'media/portfolio.jpg',
    imageAlt: 'نمایی از تجهیزات صنعتی در یکی از تصاویر آرشیوی پالپ ایران',
    caption: 'تصویر آرشیوی سایت از تجهیزات صنعتی است و به خط فلاف پالپ مشخصی نسبت داده نمی‌شود.',
    sections: [
      {
        heading: 'ابتدا محصول موردنظر را روشن کنید',
        paragraphs: [
          'گفت‌وگو درباره‌ی یک خط تولید از شناخت محصولی آغاز می‌شود که قرار است تولید شود. کاربرد نهایی، ویژگی‌های مورد انتظار و دامنه‌ی پروژه کمک می‌کنند پرسش‌های بعدی درباره‌ی مواد اولیه و تجهیزات شکل دقیق‌تری بگیرند.'
        ]
      },
      {
        heading: 'ماده‌ی اولیه را در کنار فرایند ببینید',
        paragraphs: [
          'نوع ماده‌ی اولیه، کیفیت و یکنواختی آن، شیوه‌ی تأمین و شرایط نگهداری از موضوعاتی هستند که باید در ارزیابی اولیه ثبت شوند. جزئیات آماده‌سازی و فرایند به طراحی همان پروژه وابسته است و نباید از یک نمونه‌ی عمومی نتیجه‌گیری شود.'
        ]
      },
      {
        heading: 'ماشین‌آلات را به‌صورت یک زنجیره بررسی کنید',
        paragraphs: [
          'هر بخش از خط باید در ارتباط با بخش‌های دیگر و نیازهای محل پروژه بررسی شود. فضای در دسترس، زیرساخت‌ها، نگهداری و محدوده‌ی خدمات موردنیاز، کنار مشخصات محصول و خوراک، تصویر کامل‌تری از مسئله می‌سازند.'
        ]
      },
      {
        heading: 'برای گفت‌وگوی فنی چه چیزهایی آماده کنیم؟',
        paragraphs: [
          'شرح محصول هدف، اطلاعات موجود درباره‌ی ماده‌ی اولیه، وضعیت محل اجرا و پرسش‌های باز پروژه، شروع مناسبی برای ارزیابی هستند. هر داده‌ی ناموجود را بهتر است به‌عنوان موضوع نیازمند بررسی ثبت کنیم، نه اینکه برای آن عددی فرضی در نظر بگیریم.'
        ]
      }
    ],
    related: ['feedstock', 'evaluation']
  },
  {
    id: 'feedstock',
    category: 'materials',
    categoryLabel: 'مواد اولیه',
    title: 'چطور ماده‌ی اولیه را در ارزیابی خط در نظر بگیریم؟',
    excerpt: 'از ویژگی‌های خوراک تا دسترسی و آماده‌سازی؛ نکاتی برای صورت‌بندی پرسش‌ها.',
    image: 'media/portfolio3.jpg',
    imageAlt: 'نمایی از تجهیزات صنعتی در آرشیو تصاویر پالپ ایران',
    caption: 'تصویر آرشیوی تجهیزات صنعتی است و نمونه‌ی مشخصی از فرایند این مقاله نیست.',
    sections: [
      {
        heading: 'درباره‌ی خوراک چه می‌دانیم؟',
        paragraphs: [
          'در ارزیابی اولیه، بهتر است نوع ماده‌ی اولیه، تغییرپذیری آن، نحوه‌ی تأمین و شرایط نگهداری ثبت شود. این اطلاعات زمینه‌ی پرسش‌های دقیق‌تر درباره‌ی آماده‌سازی و تناسب فرایند را فراهم می‌کنند.'
        ]
      },
      {
        heading: 'دسترسی را از فرض جدا کنید',
        paragraphs: [
          'موجودبودن یک ماده در منطقه به‌تنهایی برای تصمیم‌گیری کافی نیست. مقدار قابل‌تأمین، پیوستگی تأمین و ویژگی‌های واقعی نمونه‌ها باید بررسی شوند؛ اگر داده‌ای هنوز در دسترس نیست، آن را به‌عنوان موضوع باز نگه دارید.'
        ]
      },
      {
        heading: 'اطلاعات را به طراحی پروژه وصل کنید',
        paragraphs: [
          'مشخصات محصول موردنظر، شرایط محل اجرا و ویژگی‌های ماده‌ی اولیه باید در کنار هم بررسی شوند. انتخاب تجهیزات یا نتیجه‌گیری فنی بدون این زمینه، از یک نمونه‌ی عمومی قابل استنتاج نیست.'
        ]
      }
    ],
    related: ['fluff-start', 'evaluation']
  },
  {
    id: 'evaluation',
    category: 'planning',
    categoryLabel: 'راه‌اندازی و ارزیابی',
    title: 'پیش از ارزیابی ماشین‌آلات چه اطلاعاتی آماده کنیم؟',
    excerpt: 'فهرستی کوتاه از اطلاعات پروژه که گفت‌وگوی فنی را دقیق‌تر می‌کند.',
    image: 'media/portfolio2.jpg',
    imageAlt: 'نمایی از محیط صنعتی در آرشیو تصاویر پالپ ایران',
    caption: 'این تصویر از آرشیو سایت انتخاب شده و به‌عنوان سابقه‌ی پروژه‌ی مشخصی معرفی نمی‌شود.',
    sections: [
      {
        heading: 'هدف پروژه را توصیف کنید',
        paragraphs: [
          'شرح محصول و کاربرد موردنظر کمک می‌کند محدوده‌ی ارزیابی روشن شود. اگر بخشی از نیاز هنوز مشخص نیست، آن را در فهرست پرسش‌ها نگه دارید تا در مشاوره بررسی شود.'
        ]
      },
      {
        heading: 'وضعیت مواد اولیه و محل اجرا را ثبت کنید',
        paragraphs: [
          'اطلاعاتی که درباره‌ی ماده‌ی اولیه، محل اجرا، زیرساخت‌ها و محدودیت‌های محیطی در اختیار دارید جمع‌آوری کنید. نبودن داده هم بخشی از وضعیت واقعی پروژه است و نباید با عدد یا فرض ساختگی جایگزین شود.'
        ]
      },
      {
        heading: 'محدوده‌ی خدمات را مشخص کنید',
        paragraphs: [
          'مشخص کنید برای کدام بخش‌ها به ارزیابی، طراحی، ساخت، نصب یا راه‌اندازی نیاز دارید. پس از روشن‌شدن محدوده، می‌توان درباره‌ی اطلاعات تکمیلی و مراحل بعدی گفت‌وگو کرد.'
        ]
      }
    ],
    related: ['fluff-start', 'feedstock']
  },
  {
    id: 'bagasse',
    category: 'materials',
    categoryLabel: 'مواد اولیه',
    title: 'برای ارزیابی خمیر از باگاس چه پرسش‌هایی مطرح است؟',
    excerpt: 'موضوعاتی برای ثبت درباره‌ی خوراک، نیاز محصول و داده‌های در دسترس پروژه.',
    image: 'media/portfolio-teamwork.jpg',
    imageAlt: 'نمایی از افراد در محیط صنعتی آرشیو پالپ ایران',
    caption: 'تصویر آرشیوی یک محیط صنعتی است و به فرایند یا پروژه‌ی مشخصی نسبت داده نمی‌شود.',
    sections: [
      {
        heading: 'درباره‌ی ماده‌ی اولیه چه اطلاعاتی ثبت کنیم؟',
        paragraphs: [
          'برای آغاز ارزیابی، نوع خوراک، میزان تغییرپذیری، شیوه‌ی تأمین و شرایط نگهداری را تا جایی که داده‌ی واقعی در دسترس است ثبت کنید. این موارد پرسش‌های بعدی درباره‌ی آماده‌سازی و تناسب فرایند را روشن‌تر می‌کنند.'
        ]
      },
      {
        heading: 'نیاز محصول را کنار ویژگی خوراک بگذارید',
        paragraphs: [
          'ویژگی‌های محصول هدف و اطلاعات واقعی خوراک باید هم‌زمان بررسی شوند. یک متن آموزشی عمومی نمی‌تواند جای آزمون نمونه یا ارزیابی ویژه‌ی پروژه را بگیرد.'
        ]
      },
      {
        heading: 'داده‌های ناموجود را شفاف نگه دارید',
        paragraphs: [
          'اگر درباره‌ی دسترسی، کیفیت یا آماده‌سازی اطلاعات کافی وجود ندارد، آن را به‌عنوان موضوع باز ثبت کنید. از برآوردهای فرضی برای نتیجه‌گیری فنی استفاده نکنید.'
        ]
      }
    ],
    related: ['feedstock', 'evaluation']
  }
];

const filterButtons = [...document.querySelectorAll('[data-filter]')];
const postRows = [...document.querySelectorAll('.article-card[data-category]')];
const mobileFilter = document.querySelector('#mobile-topic-filter');
const searchInput = document.querySelector('#article-search');
const searchForm = document.querySelector('#blog-search-form');
let selectedCategory = 'all';

function normalizeSearch(value) {
  return value
    .trim()
    .replace(/[\u064B-\u065F\u0670]/g, '')
    .replace(/ي/g, 'ی')
    .replace(/ك/g, 'ک')
    .toLocaleLowerCase('fa');
}

function setCategoryFilter(category = selectedCategory, query = searchInput?.value || '') {
  if (!postRows.length) return;

  selectedCategory = category || 'all';
  const normalizedQuery = normalizeSearch(query);
  let visibleCount = 0;

  for (const card of postRows) {
    const categoryMatches = selectedCategory === 'all' || card.dataset.category === selectedCategory;
    const queryMatches = !normalizedQuery || normalizeSearch(card.textContent).includes(normalizedQuery);
    const isVisible = categoryMatches && queryMatches;
    card.hidden = !isVisible;
    if (isVisible) visibleCount += 1;
  }

  for (const button of filterButtons) {
    const isActive = button.dataset.filter === selectedCategory;
    button.classList.toggle('is-active', isActive);
    button.setAttribute('aria-pressed', String(isActive));
  }

  if (mobileFilter) mobileFilter.value = selectedCategory;

  const resultCount = document.querySelector('#result-count');
  const emptyResults = document.querySelector('#empty-results');
  if (resultCount) resultCount.textContent = `${visibleCount} نوشته`;
  if (emptyResults) emptyResults.hidden = visibleCount !== 0;
}

for (const button of filterButtons) {
  button.addEventListener('click', () => setCategoryFilter(button.dataset.filter));
}

if (mobileFilter) {
  mobileFilter.addEventListener('change', () => setCategoryFilter(mobileFilter.value));
}

if (searchInput) {
  searchInput.addEventListener('input', () => setCategoryFilter());
}

if (searchForm) {
  searchForm.addEventListener('submit', event => {
    event.preventDefault();
    setCategoryFilter();
    document.querySelector('#articles')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  });
}

for (const categoryLink of document.querySelectorAll('[data-category-link]')) {
  categoryLink.addEventListener('click', event => {
    event.preventDefault();
    setCategoryFilter(categoryLink.dataset.categoryLink);
    document.querySelector('#articles')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  });
}

if (postRows.length) {
  const requestedCategory = new URLSearchParams(window.location.search).get('category');
  const validCategory = ['fluff', 'materials', 'planning'].includes(requestedCategory) ? requestedCategory : 'all';
  const requestedQuery = new URLSearchParams(window.location.search).get('q') || '';
  if (searchInput) searchInput.value = requestedQuery;
  setCategoryFilter(validCategory, requestedQuery);
}

function renderArticle(article) {
  const articleView = document.querySelector('#article-view');
  const notFound = document.querySelector('#article-not-found');
  if (!articleView || !notFound) return;

  if (!article) {
    articleView.hidden = true;
    notFound.hidden = false;
    document.title = 'مطلب پیدا نشد | وبلاگ پالپ ایران';
    return;
  }

  articleView.hidden = false;
  notFound.hidden = true;

  const title = document.querySelector('#article-title');
  const category = document.querySelector('#article-category');
  const deck = document.querySelector('#article-deck');
  const image = document.querySelector('#article-image');
  const caption = document.querySelector('#article-caption');
  const breadcrumb = document.querySelector('#breadcrumb-category');
  const articleBody = document.querySelector('#article-body');
  const contentsList = document.querySelector('#contents-list');
  const relatedList = document.querySelector('#related-list');

  title.textContent = article.title;
  category.textContent = article.categoryLabel;
  deck.textContent = article.excerpt;
  image.src = article.image;
  image.alt = article.imageAlt;
  caption.textContent = article.caption;
  breadcrumb.textContent = article.categoryLabel;
  document.title = `${article.title} | وبلاگ پالپ ایران`;

  articleBody.replaceChildren();
  contentsList.replaceChildren();

  article.sections.forEach((section, index) => {
    const sectionId = `article-section-${index + 1}`;
    const sectionElement = document.createElement('section');
    const heading = document.createElement('h2');
    heading.id = `${sectionId}-title`;
    heading.textContent = section.heading;
    sectionElement.id = sectionId;
    sectionElement.setAttribute('aria-labelledby', heading.id);
    sectionElement.append(heading);

    for (const paragraphText of section.paragraphs) {
      const paragraph = document.createElement('p');
      paragraph.textContent = paragraphText;
      sectionElement.append(paragraph);
    }

    const listItem = document.createElement('li');
    const contentsLink = document.createElement('a');
    contentsLink.href = `#${sectionId}`;
    contentsLink.textContent = section.heading;
    listItem.append(contentsLink);
    contentsList.append(listItem);
    articleBody.append(sectionElement);
  });

  relatedList.replaceChildren();
  for (const relatedId of article.related) {
    const relatedArticle = blogArticles.find(item => item.id === relatedId);
    if (!relatedArticle) continue;
    const link = document.createElement('a');
    link.href = `blog.html?article=${encodeURIComponent(relatedArticle.id)}`;
    link.textContent = relatedArticle.title;
    relatedList.append(link);
  }
}

if (document.querySelector('#article-view')) {
  const articleId = new URLSearchParams(window.location.search).get('article') || 'fluff-start';
  renderArticle(blogArticles.find(article => article.id === articleId));
}