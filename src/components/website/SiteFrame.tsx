import type { JSX, ReactNode } from 'react';

import { websiteText } from '../../app-state';

function SiteLink({
    children,
    className,
    href,
}: {
    children: ReactNode;
    className?: string;
    href: string;
}): JSX.Element {
    return (
        <a className={className} href={href}>
            {children}
        </a>
    );
}

export function SiteHeader(): JSX.Element {
    return (
        <header className='site-header'>
            <SiteLink className='site-brand' href='/'>
                <img
                    aria-hidden='true'
                    className='site-brand__icon'
                    height='40'
                    src='/icon.svg'
                    width='40'
                />
                <span>{websiteText.brand}</span>
            </SiteLink>
            <nav aria-label={websiteText.navigation.label} className='site-nav'>
                <SiteLink href='/support'>
                    {websiteText.navigation.support}
                </SiteLink>
                <SiteLink className='site-nav__action' href='/app'>
                    {websiteText.navigation.play}
                </SiteLink>
            </nav>
        </header>
    );
}

export function SiteFooter(): JSX.Element {
    return (
        <footer className='site-footer'>
            <span>{websiteText.footer.copyright}</span>
            <nav aria-label={websiteText.footer.label}>
                <SiteLink href='/support'>
                    {websiteText.navigation.support}
                </SiteLink>
                <SiteLink href='/privacy'>
                    {websiteText.navigation.privacy}
                </SiteLink>
            </nav>
        </footer>
    );
}

export function LegalPage({
    children,
    eyebrow,
    intro,
    title,
}: {
    children: ReactNode;
    eyebrow: string;
    intro: string;
    title: string;
}): JSX.Element {
    return (
        <main className='site-page site-page--legal'>
            <div className='site-shell'>
                <SiteHeader />
                <article className='legal-page'>
                    <header className='legal-hero'>
                        <p className='site-eyebrow'>{eyebrow}</p>
                        <h1>{title}</h1>
                        <p>{intro}</p>
                    </header>
                    <div className='legal-content'>{children}</div>
                </article>
                <SiteFooter />
            </div>
        </main>
    );
}
