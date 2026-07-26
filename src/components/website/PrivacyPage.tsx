import type { JSX } from 'react';

import { websiteText } from '../../app-state';
import { LegalPage } from './SiteFrame';

export function PrivacyPage(): JSX.Element {
    const copy = websiteText.privacy;

    return (
        <LegalPage eyebrow={copy.eyebrow} intro={copy.intro} title={copy.title}>
            <p className='legal-updated'>{copy.updated}</p>
            {copy.sections.map((section) => (
                <section className='legal-section' key={section.title}>
                    <h2>{section.title}</h2>
                    {'body' in section
                        ? section.body.map((paragraph) => (
                              <p key={paragraph}>{paragraph}</p>
                          ))
                        : undefined}
                    {'items' in section ? (
                        <ul>
                            {section.items.map((item) => (
                                <li key={item}>{item}</li>
                            ))}
                        </ul>
                    ) : undefined}
                </section>
            ))}
            <section className='legal-section'>
                <h2>{copy.contactTitle}</h2>
                <p>
                    {copy.contactBody}{' '}
                    <a
                        href={`mailto:${websiteText.supportEmail}?subject=Atomize%20Privacy`}
                    >
                        {websiteText.supportEmail}
                    </a>
                    .
                </p>
            </section>
        </LegalPage>
    );
}
