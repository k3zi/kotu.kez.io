import React from 'react';
import { withRouter } from 'react-router';
import { LinkContainer } from 'react-router-bootstrap';
import FadeIn from 'react-fade-in';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import ButtonGroup from 'react-bootstrap/ButtonGroup';
import Col from 'react-bootstrap/Col';
import Dropdown from 'react-bootstrap/Dropdown';
import Form from 'react-bootstrap/Form';
import ListGroup from 'react-bootstrap/ListGroup';
import Pagination from 'react-bootstrap-4-pagination';
import Row from 'react-bootstrap/Row';
import Table from 'react-bootstrap/Table';
import ToggleButton from 'react-bootstrap/ToggleButton';

class Search extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            query: '',
            isLoading: false,
            option: null,
            isAudiobook: false,
            options: [
                {
                    endpoint: '/api/dictionary/search',
                    name: 'Words',
                    value: 'words'
                },
                {
                    endpoint: '/api/media/youtube/subtitles/search',
                    name: 'YouTube',
                    value: 'youtube'
                },
                {
                    endpoint: '/api/media/anki/subtitles/search',
                    name: 'Other',
                    value: 'other'
                }
            ],
            results: [],
            metadata: {
                page: 1,
                per: 15,
                total: 0
            }
        };
    }

    componentDidMount() {
        this.load();
    }

    componentDidUpdate(prevProps, prevState) {
        const audiobook = this.getQueryParam('audiobook') === 'true';
        if (
            this.props.match.params.query != prevProps.match.params.query
            || this.props.match.params.optionValue != prevProps.match.params.optionValue
            || this.props.match.params.page != prevProps.match.params.page
            || this.props.match.params.per != prevProps.match.params.per
            || this.state.isAudiobook != audiobook) {
            this.setState({ isAudiobook: audiobook });
            this.load();
        }
    }

    getQueryParam(key) {
        return new URLSearchParams(window.location.search).get(key);
    }

    async load() {
        const query = this.props.match.params.query;
        const optionValue = this.props.match.params.optionValue;
        const option = this.state.options.filter(o => o.value === optionValue)[0] || this.state.options[0];
        const page = this.props.match.params.page || 1;
        const per = this.props.match.params.per || this.state.metadata.per;

        this.state.metadata.page = page;
        this.state.metadata.per = per;

        this.setState({
            option,
            results: option != this.state.option ? [] : this.state.results,
            isLoading: true
        });
        if (!query || query.length === 0) {
            return;
        }
        const response = await fetch(`${option.endpoint}?page=${page}&per=${per}&q=${query}&audiobook=${this.getQueryParam('audiobook') === 'true' ? 'true' : 'false'}`);
        if (response.ok) {
            const result = await response.json();

            this.setState({
                results: result.items,
                metadata: result.metadata,
                isLoading: false
            });
        }
    }

    loadPage(page) {
        this.search(this.props.match.params.query, page);
    }

    loadOption(option) {
        this.search(this.props.match.params.query, 1, option);
    }

    async search(query, page, newOption, newAudiobook) {
        const option = newOption || this.state.option || this.state.options[0];
        const audiobook = typeof newAudiobook !== 'undefined' ? newAudiobook : this.state.isAudiobook;
        const metadata = this.state.metadata;
        metadata.page = page;
        query = query || '';
        const params = `${option.value}/${page}/${this.state.metadata.per}?audiobook=${audiobook ? 'true' : 'false'}`;
        if (!query || query.length === 0) {
            this.props.history.push(`/search/${params}`);
        } else {
            this.props.history.push(`/search/${encodeURIComponent(query)}/${params}`);
        }
    }

    toggleIsAudiobook(e) {
        this.search(this.props.match.params.query, 1, undefined, e.target.checked);
    }

    render() {
        return (
            <div>
                <h2>Search</h2>
                <Form.Control autoComplete='off' className='text-center' type="text" onChange={(e) => this.search(decodeURIComponent(e.target.value || ''), 1)} placeholder="Search" value={(this.props.match.params.query && this.props.match.params.query.length > 0) ? decodeURIComponent(this.props.match.params.query) : ''} />
                <ButtonGroup className='my-3 d-flex' toggle>
                    {this.state.options.map((option, i) => (
                        <ToggleButton
                            id={option.value}
                            key={i}
                            type="radio"
                            variant="secondary"
                            name="option"
                            value={option.value}
                            checked={this.state.option && this.state.option.value === option.value}
                            onChange={() => this.loadOption(option)}>
                            {option.name}
                        </ToggleButton>
                    ))}
                </ButtonGroup>
                {this.state.option && this.state.option.value === 'other' && <Form.Group className='mb-3' controlId="searchFilters">
                    <Form.Check inline type="checkbox" label="Audiobook" name='isAudiobook' defaultChecked={this.state.isAudiobook || this.getQueryParam('audiobook') === 'true'} onChange={(e) => this.toggleIsAudiobook(e)} />
                </Form.Group>}
                {this.props.match.params.query && this.props.match.params.query.length > 0 && <FadeIn>
                    <hr />
                    {this.state.option && this.state.option.value === 'words' && <ListGroup>
                        <FadeIn>
                            {this.state.results.map((r, i) => {
                              return <ListGroup.Item action active={false} className='d-flex align-items-center text-break text-wrap' onClick={() => this.props.onSelectWord(r)} style={{ 'white-space': 'normal' }} eventKey={i} key={i}>
                                  <img className='me-2' height='20px' src={`/api/dictionary/icon/${r.dictionary.id}`} />
                                  <span dangerouslySetInnerHTML={{ __html: r.headline.replace(new RegExp(`${this.props.match.params.query}`, 'gi'), `<mark class='p-0'>${this.props.match.params.query}</mark>`)}}></span>
                              </ListGroup.Item>;
                          })}
                      </FadeIn>
                    </ListGroup>}

                    {this.state.option && this.state.option.value === 'youtube' && <ListGroup>
                        <FadeIn>
                            {this.state.results.map((s, i) => {
                                return <LinkContainer key={i} to={`/media/youtube/${s.youtubeVideo.youtubeID}/${s.startTime}`}>
                                    <ListGroup.Item action className='d-flex align-items-center text-break text-wrap' as="button" style={{ 'white-space': 'normal' }} eventKey={i} >
                                        <img className='me-2' height='40px' src={s.youtubeVideo.thumbnailURL} />
                                        <span dangerouslySetInnerHTML={{ __html: s.text.replace(new RegExp(`${this.props.match.params.query}`, 'gi'), `<mark class='p-0'>${this.props.match.params.query}</mark>`)}}></span>
                                    </ListGroup.Item>
                                </LinkContainer>;
                            })}
                        </FadeIn>
                    </ListGroup>}

                    {this.state.option && this.state.option.value === 'other' && <ListGroup>
                        <FadeIn>
                            {this.state.results.map((s, i) => {
                                return <ListGroup.Item action key={i} onClick={() => this.props.onPlayAudio(`/api/media/external/audio/${s.externalFile.id}`)} className='text-break text-wrap' as="button" style={{ 'white-space': 'normal' }} eventKey={i} >
                                    <span dangerouslySetInnerHTML={{ __html: s.text.replace(new RegExp(`${this.props.match.params.query}`, 'gi'), `<mark class='p-0'>${this.props.match.params.query}</mark>`)}}></span>
                                    <br />
                                    <small>{s.video.title}</small>
                                </ListGroup.Item>;
                            })}
                        </FadeIn>
                    </ListGroup>}
                    <Pagination className='mt-3' totalPages={Math.ceil(this.state.metadata.total / this.state.metadata.per)} currentPage={this.state.metadata.page} showMax={7} onClick={(i) => this.loadPage(i)} />
                </FadeIn>}
            </div>
        );
    }
}

export default withRouter(Search);
